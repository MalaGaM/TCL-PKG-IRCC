# irc.tcl --
#
#	irc implementation for Tcl.
#
# Copyright (c) 2001-2003 by David N. Welton <davidw@dedasys.com>.
# This code may be distributed under the same terms as Tcl.

# -------------------------------------------------------------------------

package require Tcl 8.6

# -------------------------------------------------------------------------

namespace eval ::IRCC {
	# counter used to differentiate connections
	variable conn					0
	variable config
	variable pkg_vers				0.0.1
	variable pkg_vers_min_need_tcl	8.6
	variable pkg_vers_min_need_tls	1.7.20
	variable irctclfile				[info script]
	array set config	{
		debug	0
		logger	0
	}
}

# ::IRCC::config --
#
# Set global configuration options.
#
# Arguments:
#
# key	name of the configuration option to change.
#
# value	value of the configuration option.

proc ::IRCC::config { args } {
	variable config
	if { [llength $args] == 0 } {
		return [array get config]
	} elseif { [llength $args] == 1 } {
		set key	[lindex $args 0]
		return $config($key)
	} elseif { [llength $args] > 2 } {
		error "wrong # args: should be \"config key ?val?\""
	}
	set key		[lindex $args 0]
	set value	[lindex $args 1]
	foreach ns [namespace children] {
		if {
			[info exists config($key)]							\
				&&	[info exists ${ns}::config($key)]			\
				&&	[set ${ns}::config($key)] == $config($key)
		} {
			${ns}::cmd-config $key $value
		}
	}
	set config($key)	$value
}

# ::IRCC::connections --
#
# Return a list of handles to all existing connections

proc ::IRCC::connections { } {
	set r	{}
	foreach ns [namespace children] {
		lappend r ${ns}::network
	}
	return $r
}

# ::IRCC::reload --
#
# Reload this file, and merge the current connections into
# the new one.

proc ::IRCC::reload { } {
	variable conn
	set oldconn	$conn
	namespace eval :: {
		source [set ::IRCC::irctclfile]
	}
	foreach ns [namespace children] {
		foreach var {sock logger host port} {
			set $var	[set ${ns}::$var]
		}
		array set dispatch	[array get ${ns}::dispatch]
		array set config	[array get ${ns}::config]
		# make sure our new connection uses the same namespace
		set conn			[string range $ns 10 end]
		::IRCC::connection
		foreach var {sock logger host port} {
			set ${ns}::$var		[set $var]
		}
		array set ${ns}::dispatch	[array get dispatch]
		array set ${ns}::config		[array get config]
	}
	set conn	$oldconn
}

# ::IRCC::connection --
#
# Create an IRC connection namespace and associated commands.

proc ::IRCC::connection { args } {
	variable conn
	variable config

	# Create a unique namespace of the form irc$conn::$host

	set name	[format "%s::IRCC%s" [namespace current] $conn]

	namespace eval $name {
		variable sock
		variable dispatch
		variable linedata
		variable config

		set sock			{}
		array set dispatch	{}
		array set linedata	{}
		array set config	[array get ::IRCC::config]
		if { $config(logger) || $config(debug) } {
			package require logger
			variable logger
			set logger		[logger::init [namespace tail [namespace current]]]
			if { !$config(debug) } { ${logger}::disable debug }
		}
		proc TLSSocketCallBack { level args } {
			set SOCKET_NAME	[lindex $args 0]
			set type		[lindex $args 1]
			set socketid	[lindex $args 2]
			set what		[lrange $args 3 end]
			cmd-log debug "Socket '$SOCKET_NAME' callback $type: $what"
			if { [string match -nocase "*certificate*verify*failed*" $what] } {
				cmd-log error "IRCC Socket erreur: Vous essayez de vous connecter a un serveur TLS auto-signé. ($what) [tls::status $socketid]"
			}	
			if { [string match -nocase "*wrong*version*number*" $what] } {
				cmd-log error "IRCC Socket erreur: Vous essayez sans doute de connecter en SSL sur un port Non-SSL. ($what)"
			}
		}

		# ircsend --
		# send text to the IRC server
		proc ircsend { msg } {
			variable sock
			variable dispatch
			if { $sock eq "" } { return }
			cmd-log debug "ircsend: '$msg'"
			if { [catch {puts $sock $msg} err] } {
				catch { close $sock }
				set sock	{}
				if { [info exists dispatch(EOF)] } {
					eval $dispatch(EOF)
				}
				cmd-log error "Error in ircsend: $err"
			}
		}


		#########################################################
		# Implemented user-side commands, meaning that these commands
		# cause the calling user to perform the given action.
		#########################################################
		# cmd-config --
		#
		# Set or return per-connection configuration options.
		#
		# Arguments:
		#
		# key	name of the configuration option to change.
		#
		# value	value (optional) of the configuration option.

		proc cmd-config { args } {
			variable config
			variable logger

			if { [llength $args] == 0 } {
				return [array get config]
			} elseif { [llength $args] == 1 } {
				set key	[lindex $args 0]
				return $config($key)
			} elseif { [llength $args] > 2 } {
				error "wrong # args: should be \"config key ?val?\""
			}
			set key		[lindex $args 0]
			set value	[lindex $args 1]
			if { $key eq "debug" } {
				if {$value} {
					if { !$config(logger) } { cmd-config logger 1 }
					${logger}::enable debug
				} elseif { [info exists logger] } {
					${logger}::disable debug
				}
			}
			if { $key eq "logger" } {
				if { $value && !$config(logger)} {
					package require logger
					set logger	[logger::init [namespace tail [namespace current]]]
				} elseif { [info exists logger] } {
					${logger}::delete
					unset	logger
				}
			}
			set config($key)	$value
		}

		proc cmd-log {level text} {
			variable logger
			if { ![info exists logger] } return
			${logger}::$level $text
		}

		proc cmd-logname { } {
			variable logger
			if { ![info exists logger] } return
			return $logger
		}

		# cmd-destroy --
		#
		# destroys the current connection and its namespace

		proc cmd-destroy { } {
			variable logger
			variable sock
			if { [info exists logger] } { ${logger}::delete }
			catch {close $sock}
			namespace delete [namespace current]
		}

		proc cmd-connected { } {
			variable sock
			if { $sock eq "" } { return 0 }
			return 1
		}

		# http://abcdrfc.free.fr/rfc-vf/rfc1459.html#412
		proc cmd-user { nickname username {userinfo {TCL PACKAGE IRCC - https://git.io/JY7tI}} } {
			ircsend "NICK $nickname"
			ircsend "USER $username * * :$userinfo"
		}

		proc cmd-nick { nk } {
			ircsend "NICK $nk"
		}

		proc cmd-ping { target } {
			ircsend "PRIVMSG $target :\001PING [clock seconds]\001"
		}

		proc cmd-serverping { } {
			ircsend "PING [clock seconds]"
		}

		proc cmd-ctcp { target line } {
			ircsend "PRIVMSG $target :\001$line\001"
		}

		proc cmd-join { chan {key {}} } {
			ircsend "JOIN $chan $key"
		}

		proc cmd-part { chan {msg {TCL PACKAGE IRCC - https://git.io/JY7tI}} } {
			if { $msg eq "" } {
				ircsend "PART $chan"
			} else {
				ircsend "PART $chan :$msg"
			}
		}

		proc cmd-quit { {msg {TCL PACKAGE IRCC - https://git.io/JY7tI}} } {
			ircsend "QUIT :$msg"
		}

		proc cmd-privmsg { target msg } {
			ircsend "PRIVMSG $target :$msg"
		}

		proc cmd-notice { target msg } {
			ircsend "NOTICE $target :$msg"
		}

		proc cmd-kick { chan target {msg {}} } {
			ircsend "KICK $chan $target :$msg"
		}

		proc cmd-mode { target args } {
			ircsend "MODE $target [join $args]"
		}

		proc cmd-topic { chan msg } {
			ircsend "TOPIC $chan :$msg"
		}

		proc cmd-invite { chan target } {
			ircsend "INVITE $target $chan"
		}

		proc cmd-send { line } {
			ircsend $line
		}

		proc cmd-peername { } {
			variable sock
			if { $sock eq "" } { return {} }
			return [fconfigure $sock -peername]
		}

		proc cmd-sockname { } {
			variable sock
			if { $sock eq "" } { return {} }
			return [fconfigure $sock -sockname]
		}

		proc cmd-socket { } {
			variable sock
			return $sock
		}

		proc cmd-disconnect { } {
			variable sock
			if { $sock eq "" } { return -1 }
			catch { close $sock }
			set sock	{}
			return 0
		}

		# Connect --
		# Create the actual tcp connection.
		# http://abcdrfc.free.fr/rfc-vf/rfc1459.html#41
		proc cmd-connect { IRC_HOSTNAME {IRC_PORT +6697} {IRC_PASSWORD ""} } {
			variable sock
			variable host
			variable port

			set host	$IRC_HOSTNAME
			set s_port	$IRC_PORT
			if { [string range $s_port 0 0] == "+" } {
				set secure	1;
				set port	[string range $s_port 1 end]
			} else {
				set secure	0;
				set port	$s_port
			}
			if { $secure == 1 } {
				package require tls $::IRCC::pkg_vers_min_need_tls
				set socket_binary	"::tls::socket -require 0 -request 0 -command \"[namespace current]::TLSSocketCallBack $sock\""
			} else {
				set socket_binary	::socket
			}
			if { $sock eq "" } {
				set sock	[{*}$socket_binary $host $port]
				fconfigure $sock -translation crlf -buffering line
				fileevent $sock readable [namespace current]::GetEvent
				if { $IRC_PASSWORD != "" } {
						ircsend	"PASS $IRC_PASSWORD"
				}
				
			}
			return 0
		}

		# Callback API:

		# These are all available from within callbacks, so as to
		# provide an interface to provide some information on what is
		# coming out of the server.

		# action --

		# Action returns the action performed, such as KICK, PRIVMSG,
		# MODE etc, including numeric actions such as 001, 252, 353,
		# and so forth.

		proc action { } {
			variable linedata
			return $linedata(action)
		}

		# msg --

		# The last argument of the line, after the last ':'.

		proc msg { } {
			variable linedata
			return $linedata(msg)
		}

		# who --

		# Who performed the action.  If the command is called as [who address],
		# it returns the information in the form
		# nick!ident@host.domain.net

		proc who { {address 0} } {
			variable linedata
			if { $address == 0 } {
				return [lindex [split $linedata(who) !] 0]
			} else {
				return $linedata(who)
			}
		}

		# target --

		# To whom was this action done.

		proc target { } {
			variable linedata
			return $linedata(target)
		}

		# additional --

		# Returns any additional header elements beyond the target as a list.

		proc additional { } {
			variable linedata
			return $linedata(additional)
		}

		# header --

		# Returns the entire header in list format.

		proc header { } {
			variable linedata
			return [concat [list $linedata(who) $linedata(action) \
				$linedata(target)] $linedata(additional)]
		}

		# GetEvent --

		# Get a line from the server and dispatch it.

		proc GetEvent { } {
			variable linedata
			variable sock
			variable dispatch
			array set linedata	{}
			set line			"eof"
			if { [eof $sock] || [catch {gets $sock} line] } {
				close $sock
				set sock	{}
				cmd-log error "Error receiving from network: $line"
				if { [info exists dispatch(EOF)] } {
					eval $dispatch(EOF)
				}
				return
			}
			cmd-log debug "Recieved: $line"
			if { [set pos			[string first " :" $line]] > -1 } {
				set header			[string range $line 0 [expr {$pos - 1}]]
				set linedata(msg)	[string range $line [expr {$pos + 2}] end]
			} else {
				set header			[string trim $line]
				set linedata(msg)	{}
			}

			if { [string match :* $header] } {
				set header	[split [string trimleft $header :]]
			} else {
				set header	[linsert [split $header] 0 {}]
			}
			set linedata(who)			[lindex $header 0]
			set linedata(action)		[lindex $header 1]
			set linedata(target)		[lindex $header 2]
			set linedata(additional)	[lrange $header 3 end]
			if { [info exists dispatch($linedata(action))] } {
				eval $dispatch($linedata(action))
			} elseif { [string match {[0-9]??} $linedata(action)] } {
				eval $dispatch(defaultnumeric)
			} elseif { $linedata(who) eq "" } {
				eval $dispatch(defaultcmd)
			} else {
				eval $dispatch(defaultevent)
			}
		}

		# registerevent --

		# Register an event in the dispatch table.

		# Arguments:
		# evnt: name of event as sent by IRC server.
		# cmd: proc to register as the event handler

		proc cmd-registerevent { evnt cmd } {
			variable dispatch
			set dispatch($evnt)	$cmd
			if { $cmd eq "" } {
				unset dispatch($evnt)
			}
		}

		# getevent --

		# Return the currently registered handler for the event.

		# Arguments:
		# evnt: name of event as sent by IRC server.

		proc cmd-getevent { evnt } {
			variable dispatch
			if { [info exists dispatch($evnt)] } {
				return $dispatch($evnt)
			}
			return {}
		}

		# eventexists --

		# Return a boolean value indicating if there is a handler
		# registered for the event.

		# Arguments:
		# evnt: name of event as sent by IRC server.

		proc cmd-eventexists { evnt } {
			variable dispatch
			return [info exists dispatch($evnt)]
		}

		# network --

		# Accepts user commands and dispatches them.

		# Arguments:
		# cmd: command to invoke
		# args: arguments to the command

		proc network { cmd args } {
			eval [linsert $args 0 [namespace current]::cmd-$cmd]
		}

		# Create default handlers.

		set dispatch(PING)				{network send "PONG :[msg]"}
		set dispatch(defaultevent)		#
		set dispatch(defaultcmd)		#
		set dispatch(defaultnumeric)	#
	}

	set returncommand	[format "%s::IRCC%s::network" [namespace current] $conn]
	incr conn
	return $returncommand
}

# -------------------------------------------------------------------------

package provide IRCC $::IRCC::pkg_vers
package require Tcl $::IRCC::pkg_vers_min_need_tcl
package require tls $::IRCC::pkg_vers_min_need_tls

# -------------------------------------------------------------------------
return
