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
proc ::IRCC::num2name { numeric } {
	if { $numeric == "001" } {
		return "RPL_WELCOME";
	} elseif { $numeric == "002" } {
		return "RPL_YOURHOST";
	} elseif { $numeric == "003" } {
		return "RPL_CREATED";
	} elseif { $numeric == "004" } {
		return "RPL_MYINFO";
	} elseif { $numeric == "004" } {
		return "RPL_MYINFO";
	} elseif { $numeric == "005" } {
		return "RPL_BOUNCE";
	} elseif { $numeric == "005" } {
		return "RPL_ISUPPORT";
	} elseif { $numeric == "006" } {
		return "RPL_MAP";
	} elseif { $numeric == "007" } {
		return "RPL_MAPEND";
	} elseif { $numeric == "008" } {
		return "RPL_SNOMASK";
	} elseif { $numeric == "009" } {
		return "RPL_STATMEMTOT";
	} elseif { $numeric == "010" } {
		return "RPL_BOUNCE";
	} elseif { $numeric == "010" } {
		return "RPL_STATMEM";
	} elseif { $numeric == "014" } {
		return "RPL_YOURCOOKIE";
	} elseif { $numeric == "015" } {
		return "RPL_MAP";
	} elseif { $numeric == "016" } {
		return "RPL_MAPMORE";
	} elseif { $numeric == "017" } {
		return "RPL_MAPEND";
	} elseif { $numeric == "042" } {
		return "RPL_YOURID";
	} elseif { $numeric == "043" } {
		return "RPL_SAVENICK";
	} elseif { $numeric == "050" } {
		return "RPL_ATTEMPTINGJUNC";
	} elseif { $numeric == "051" } {
		return "RPL_ATTEMPTINGREROUTE";
	} elseif { $numeric == "200" } {
		return "RPL_TRACELINK";
	} elseif { $numeric == "201" } {
		return "RPL_TRACECONNECTING";
	} elseif { $numeric == "202" } {
		return "RPL_TRACEHANDSHAKE";
	} elseif { $numeric == "203" } {
		return "RPL_TRACEUNKNOWN";
	} elseif { $numeric == "204" } {
		return "RPL_TRACEOPERATOR";
	} elseif { $numeric == "205" } {
		return "RPL_TRACEUSER";
	} elseif { $numeric == "206" } {
		return "RPL_TRACESERVER";
	} elseif { $numeric == "207" } {
		return "RPL_TRACESERVICE";
	} elseif { $numeric == "208" } {
		return "RPL_TRACENEWTYPE";
	} elseif { $numeric == "209" } {
		return "RPL_TRACECLASS";
	} elseif { $numeric == "210" } {
		return "RPL_TRACERECONNECT";
	} elseif { $numeric == "210" } {
		return "RPL_STATS";
	} elseif { $numeric == "211" } {
		return "RPL_STATSLINKINFO";
	} elseif { $numeric == "212" } {
		return "RPL_STATSCOMMANDS";
	} elseif { $numeric == "213" } {
		return "RPL_STATSCLINE";
	} elseif { $numeric == "214" } {
		return "RPL_STATSNLINE";
	} elseif { $numeric == "215" } {
		return "RPL_STATSILINE";
	} elseif { $numeric == "216" } {
		return "RPL_STATSKLINE";
	} elseif { $numeric == "217" } {
		return "RPL_STATSQLINE";
	} elseif { $numeric == "217" } {
		return "RPL_STATSPLINE";
	} elseif { $numeric == "218" } {
		return "RPL_STATSYLINE";
	} elseif { $numeric == "219" } {
		return "RPL_ENDOFSTATS";
	} elseif { $numeric == "220" } {
		return "RPL_STATSPLINE";
	} elseif { $numeric == "220" } {
		return "RPL_STATSBLINE";
	} elseif { $numeric == "221" } {
		return "RPL_UMODEIS";
	} elseif { $numeric == "222" } {
		return "RPL_MODLIST";
	} elseif { $numeric == "222" } {
		return "RPL_SQLINE_NICK";
	} elseif { $numeric == "222" } {
		return "RPL_STATSBLINE";
	} elseif { $numeric == "223" } {
		return "RPL_STATSELINE";
	} elseif { $numeric == "223" } {
		return "RPL_STATSGLINE";
	} elseif { $numeric == "224" } {
		return "RPL_STATSFLINE";
	} elseif { $numeric == "224" } {
		return "RPL_STATSTLINE";
	} elseif { $numeric == "225" } {
		return "RPL_STATSDLINE";
	} elseif { $numeric == "225" } {
		return "RPL_STATSZLINE";
	} elseif { $numeric == "225" } {
		return "RPL_STATSELINE";
	} elseif { $numeric == "226" } {
		return "RPL_STATSCOUNT";
	} elseif { $numeric == "226" } {
		return "RPL_STATSNLINE";
	} elseif { $numeric == "227" } {
		return "RPL_STATSGLINE";
	} elseif { $numeric == "227" } {
		return "RPL_STATSVLINE";
	} elseif { $numeric == "228" } {
		return "RPL_STATSQLINE";
	} elseif { $numeric == "231" } {
		return "RPL_SERVICEINFO";
	} elseif { $numeric == "232" } {
		return "RPL_ENDOFSERVICES";
	} elseif { $numeric == "232" } {
		return "RPL_RULES";
	} elseif { $numeric == "233" } {
		return "RPL_SERVICE";
	} elseif { $numeric == "234" } {
		return "RPL_SERVLIST";
	} elseif { $numeric == "235" } {
		return "RPL_SERVLISTEND";
	} elseif { $numeric == "236" } {
		return "RPL_STATSVERBOSE";
	} elseif { $numeric == "237" } {
		return "RPL_STATSENGINE";
	} elseif { $numeric == "238" } {
		return "RPL_STATSFLINE";
	} elseif { $numeric == "239" } {
		return "RPL_STATSIAUTH";
	} elseif { $numeric == "240" } {
		return "RPL_STATSVLINE";
	} elseif { $numeric == "240" } {
		return "RPL_STATSXLINE";
	} elseif { $numeric == "241" } {
		return "RPL_STATSLLINE";
	} elseif { $numeric == "242" } {
		return "RPL_STATSUPTIME";
	} elseif { $numeric == "243" } {
		return "RPL_STATSOLINE";
	} elseif { $numeric == "244" } {
		return "RPL_STATSHLINE";
	} elseif { $numeric == "245" } {
		return "RPL_STATSSLINE";
	} elseif { $numeric == "246" } {
		return "RPL_STATSPING";
	} elseif { $numeric == "246" } {
		return "RPL_STATSTLINE";
	} elseif { $numeric == "246" } {
		return "RPL_STATSULINE";
	} elseif { $numeric == "247" } {
		return "RPL_STATSBLINE";
	} elseif { $numeric == "247" } {
		return "RPL_STATSXLINE";
	} elseif { $numeric == "247" } {
		return "RPL_STATSGLINE";
	} elseif { $numeric == "248" } {
		return "RPL_STATSULINE";
	} elseif { $numeric == "248" } {
		return "RPL_STATSDEFINE";
	} elseif { $numeric == "249" } {
		return "RPL_STATSULINE";
	} elseif { $numeric == "249" } {
		return "RPL_STATSDEBUG";
	} elseif { $numeric == "250" } {
		return "RPL_STATSDLINE";
	} elseif { $numeric == "250" } {
		return "RPL_STATSCONN";
	} elseif { $numeric == "251" } {
		return "RPL_LUSERCLIENT";
	} elseif { $numeric == "252" } {
		return "RPL_LUSEROP";
	} elseif { $numeric == "253" } {
		return "RPL_LUSERUNKNOWN";
	} elseif { $numeric == "254" } {
		return "RPL_LUSERCHANNELS";
	} elseif { $numeric == "255" } {
		return "RPL_LUSERME";
	} elseif { $numeric == "256" } {
		return "RPL_ADMINME";
	} elseif { $numeric == "257" } {
		return "RPL_ADMINLOC1";
	} elseif { $numeric == "258" } {
		return "RPL_ADMINLOC2";
	} elseif { $numeric == "259" } {
		return "RPL_ADMINEMAIL";
	} elseif { $numeric == "261" } {
		return "RPL_TRACELOG";
	} elseif { $numeric == "262" } {
		return "RPL_TRACEPING";
	} elseif { $numeric == "262" } {
		return "RPL_TRACEEND";
	} elseif { $numeric == "263" } {
		return "RPL_TRYAGAIN";
	} elseif { $numeric == "265" } {
		return "RPL_LOCALUSERS";
	} elseif { $numeric == "266" } {
		return "RPL_GLOBALUSERS";
	} elseif { $numeric == "267" } {
		return "RPL_START_NETSTAT";
	} elseif { $numeric == "268" } {
		return "RPL_NETSTAT";
	} elseif { $numeric == "269" } {
		return "RPL_END_NETSTAT";
	} elseif { $numeric == "270" } {
		return "RPL_PRIVS";
	} elseif { $numeric == "271" } {
		return "RPL_SILELIST";
	} elseif { $numeric == "272" } {
		return "RPL_ENDOFSILELIST";
	} elseif { $numeric == "273" } {
		return "RPL_NOTIFY";
	} elseif { $numeric == "274" } {
		return "RPL_ENDNOTIFY";
	} elseif { $numeric == "274" } {
		return "RPL_STATSDELTA";
	} elseif { $numeric == "275" } {
		return "RPL_STATSDLINE";
	} elseif { $numeric == "276" } {
		return "RPL_VCHANEXIST";
	} elseif { $numeric == "277" } {
		return "RPL_VCHANLIST";
	} elseif { $numeric == "278" } {
		return "RPL_VCHANHELP";
	} elseif { $numeric == "280" } {
		return "RPL_GLIST";
	} elseif { $numeric == "281" } {
		return "RPL_ENDOFGLIST";
	} elseif { $numeric == "281" } {
		return "RPL_ACCEPTLIST";
	} elseif { $numeric == "282" } {
		return "RPL_ENDOFACCEPT";
	} elseif { $numeric == "282" } {
		return "RPL_JUPELIST";
	} elseif { $numeric == "283" } {
		return "RPL_ALIST";
	} elseif { $numeric == "283" } {
		return "RPL_ENDOFJUPELIST";
	} elseif { $numeric == "284" } {
		return "RPL_ENDOFALIST";
	} elseif { $numeric == "284" } {
		return "RPL_FEATURE";
	} elseif { $numeric == "285" } {
		return "RPL_GLIST_HASH";
	} elseif { $numeric == "285" } {
		return "RPL_CHANINFO_HANDLE";
	} elseif { $numeric == "285" } {
		return "RPL_NEWHOSTIS";
	} elseif { $numeric == "286" } {
		return "RPL_CHANINFO_USERS";
	} elseif { $numeric == "286" } {
		return "RPL_CHKHEAD";
	} elseif { $numeric == "287" } {
		return "RPL_CHANINFO_CHOPS";
	} elseif { $numeric == "287" } {
		return "RPL_CHANUSER";
	} elseif { $numeric == "288" } {
		return "RPL_CHANINFO_VOICES";
	} elseif { $numeric == "288" } {
		return "RPL_PATCHHEAD";
	} elseif { $numeric == "289" } {
		return "RPL_CHANINFO_AWAY";
	} elseif { $numeric == "289" } {
		return "RPL_PATCHCON";
	} elseif { $numeric == "290" } {
		return "RPL_CHANINFO_OPERS";
	} elseif { $numeric == "290" } {
		return "RPL_HELPHDR";
	} elseif { $numeric == "290" } {
		return "RPL_DATASTR";
	} elseif { $numeric == "291" } {
		return "RPL_CHANINFO_BANNED";
	} elseif { $numeric == "291" } {
		return "RPL_HELPOP";
	} elseif { $numeric == "291" } {
		return "RPL_ENDOFCHECK";
	} elseif { $numeric == "292" } {
		return "RPL_CHANINFO_BANS";
	} elseif { $numeric == "292" } {
		return "RPL_HELPTLR";
	} elseif { $numeric == "293" } {
		return "RPL_CHANINFO_INVITE";
	} elseif { $numeric == "293" } {
		return "RPL_HELPHLP";
	} elseif { $numeric == "294" } {
		return "RPL_CHANINFO_INVITES";
	} elseif { $numeric == "294" } {
		return "RPL_HELPFWD";
	} elseif { $numeric == "295" } {
		return "RPL_CHANINFO_KICK";
	} elseif { $numeric == "295" } {
		return "RPL_HELPIGN";
	} elseif { $numeric == "296" } {
		return "RPL_CHANINFO_KICKS";
	} elseif { $numeric == "299" } {
		return "RPL_END_CHANINFO";
	} elseif { $numeric == "300" } {
		return "RPL_NONE";
	} elseif { $numeric == "301" } {
		return "RPL_AWAY";
	} elseif { $numeric == "301" } {
		return "RPL_AWAY";
	} elseif { $numeric == "302" } {
		return "RPL_USERHOST";
	} elseif { $numeric == "303" } {
		return "RPL_ISON";
	} elseif { $numeric == "304" } {
		return "RPL_TEXT";
	} elseif { $numeric == "305" } {
		return "RPL_UNAWAY";
	} elseif { $numeric == "306" } {
		return "RPL_NOWAWAY";
	} elseif { $numeric == "307" } {
		return "RPL_USERIP";
	} elseif { $numeric == "307" } {
		return "RPL_WHOISREGNICK";
	} elseif { $numeric == "307" } {
		return "RPL_SUSERHOST";
	} elseif { $numeric == "308" } {
		return "RPL_NOTIFYACTION";
	} elseif { $numeric == "308" } {
		return "RPL_WHOISADMIN";
	} elseif { $numeric == "308" } {
		return "RPL_RULESSTART";
	} elseif { $numeric == "309" } {
		return "RPL_NICKTRACE";
	} elseif { $numeric == "309" } {
		return "RPL_WHOISSADMIN";
	} elseif { $numeric == "309" } {
		return "RPL_ENDOFRULES";
	} elseif { $numeric == "309" } {
		return "RPL_WHOISHELPER";
	} elseif { $numeric == "310" } {
		return "RPL_WHOISSVCMSG";
	} elseif { $numeric == "310" } {
		return "RPL_WHOISHELPOP";
	} elseif { $numeric == "310" } {
		return "RPL_WHOISSERVICE";
	} elseif { $numeric == "311" } {
		return "RPL_WHOISUSER";
	} elseif { $numeric == "312" } {
		return "RPL_WHOISSERVER";
	} elseif { $numeric == "313" } {
		return "RPL_WHOISOPERATOR";
	} elseif { $numeric == "314" } {
		return "RPL_WHOWASUSER";
	} elseif { $numeric == "315" } {
		return "RPL_ENDOFWHO";
	} elseif { $numeric == "316" } {
		return "RPL_WHOISCHANOP";
	} elseif { $numeric == "317" } {
		return "RPL_WHOISIDLE";
	} elseif { $numeric == "318" } {
		return "RPL_ENDOFWHOIS";
	} elseif { $numeric == "319" } {
		return "RPL_WHOISCHANNELS";
	} elseif { $numeric == "320" } {
		return "RPL_WHOISVIRT";
	} elseif { $numeric == "320" } {
		return "RPL_WHOIS_HIDDEN";
	} elseif { $numeric == "320" } {
		return "RPL_WHOISSPECIAL";
	} elseif { $numeric == "321" } {
		return "RPL_LISTSTART";
	} elseif { $numeric == "322" } {
		return "RPL_LIST";
	} elseif { $numeric == "323" } {
		return "RPL_LISTEND";
	} elseif { $numeric == "324" } {
		return "RPL_CHANNELMODEIS";
	} elseif { $numeric == "325" } {
		return "RPL_UNIQOPIS";
	} elseif { $numeric == "325" } {
		return "RPL_CHANNELPASSIS";
	} elseif { $numeric == "326" } {
		return "RPL_NOCHANPASS";
	} elseif { $numeric == "327" } {
		return "RPL_CHPASSUNKNOWN";
	} elseif { $numeric == "328" } {
		return "RPL_CHANNEL_URL";
	} elseif { $numeric == "329" } {
		return "RPL_CREATIONTIME";
	} elseif { $numeric == "330" } {
		return "RPL_WHOWAS_TIME";
	} elseif { $numeric == "330" } {
		return "RPL_WHOISACCOUNT";
	} elseif { $numeric == "331" } {
		return "RPL_NOTOPIC";
	} elseif { $numeric == "332" } {
		return "RPL_TOPIC";
	} elseif { $numeric == "333" } {
		return "RPL_TOPICWHOTIME";
	} elseif { $numeric == "334" } {
		return "RPL_LISTUSAGE";
	} elseif { $numeric == "334" } {
		return "RPL_COMMANDSYNTAX";
	} elseif { $numeric == "334" } {
		return "RPL_LISTSYNTAX";
	} elseif { $numeric == "335" } {
		return "RPL_WHOISBOT";
	} elseif { $numeric == "338" } {
		return "RPL_CHANPASSOK";
	} elseif { $numeric == "338" } {
		return "RPL_WHOISACTUALLY";
	} elseif { $numeric == "339" } {
		return "RPL_BADCHANPASS";
	} elseif { $numeric == "340" } {
		return "RPL_USERIP";
	} elseif { $numeric == "341" } {
		return "RPL_INVITING";
	} elseif { $numeric == "342" } {
		return "RPL_SUMMONING";
	} elseif { $numeric == "345" } {
		return "RPL_INVITED";
	} elseif { $numeric == "346" } {
		return "RPL_INVITELIST";
	} elseif { $numeric == "347" } {
		return "RPL_ENDOFINVITELIST";
	} elseif { $numeric == "348" } {
		return "RPL_EXCEPTLIST";
	} elseif { $numeric == "349" } {
		return "RPL_ENDOFEXCEPTLIST";
	} elseif { $numeric == "351" } {
		return "RPL_VERSION";
	} elseif { $numeric == "352" } {
		return "RPL_WHOREPLY";
	} elseif { $numeric == "353" } {
		return "RPL_NAMREPLY";
	} elseif { $numeric == "354" } {
		return "RPL_WHOSPCRPL";
	} elseif { $numeric == "355" } {
		return "RPL_NAMREPLY_";
	} elseif { $numeric == "357" } {
		return "RPL_MAP";
	} elseif { $numeric == "358" } {
		return "RPL_MAPMORE";
	} elseif { $numeric == "359" } {
		return "RPL_MAPEND";
	} elseif { $numeric == "361" } {
		return "RPL_KILLDONE";
	} elseif { $numeric == "362" } {
		return "RPL_CLOSING";
	} elseif { $numeric == "363" } {
		return "RPL_CLOSEEND";
	} elseif { $numeric == "364" } {
		return "RPL_LINKS";
	} elseif { $numeric == "365" } {
		return "RPL_ENDOFLINKS";
	} elseif { $numeric == "366" } {
		return "RPL_ENDOFNAMES";
	} elseif { $numeric == "367" } {
		return "RPL_BANLIST";
	} elseif { $numeric == "368" } {
		return "RPL_ENDOFBANLIST";
	} elseif { $numeric == "369" } {
		return "RPL_ENDOFWHOWAS";
	} elseif { $numeric == "371" } {
		return "RPL_INFO";
	} elseif { $numeric == "372" } {
		return "RPL_MOTD";
	} elseif { $numeric == "373" } {
		return "RPL_INFOSTART";
	} elseif { $numeric == "374" } {
		return "RPL_ENDOFINFO";
	} elseif { $numeric == "375" } {
		return "RPL_MOTDSTART";
	} elseif { $numeric == "376" } {
		return "RPL_ENDOFMOTD";
	} elseif { $numeric == "377" } {
		return "RPL_KICKEXPIRED";
	} elseif { $numeric == "377" } {
		return "RPL_SPAM";
	} elseif { $numeric == "378" } {
		return "RPL_BANEXPIRED";
	} elseif { $numeric == "378" } {
		return "RPL_WHOISHOST";
	} elseif { $numeric == "378" } {
		return "RPL_MOTD";
	} elseif { $numeric == "379" } {
		return "RPL_KICKLINKED";
	} elseif { $numeric == "379" } {
		return "RPL_WHOISMODES";
	} elseif { $numeric == "380" } {
		return "RPL_BANLINKED";
	} elseif { $numeric == "380" } {
		return "RPL_YOURHELPER";
	} elseif { $numeric == "381" } {
		return "RPL_YOUREOPER";
	} elseif { $numeric == "382" } {
		return "RPL_REHASHING";
	} elseif { $numeric == "383" } {
		return "RPL_YOURESERVICE";
	} elseif { $numeric == "384" } {
		return "RPL_MYPORTIS";
	} elseif { $numeric == "385" } {
		return "RPL_NOTOPERANYMORE";
	} elseif { $numeric == "386" } {
		return "RPL_QLIST";
	} elseif { $numeric == "386" } {
		return "RPL_IRCOPS";
	} elseif { $numeric == "387" } {
		return "RPL_ENDOFQLIST";
	} elseif { $numeric == "387" } {
		return "RPL_ENDOFIRCOPS";
	} elseif { $numeric == "388" } {
		return "RPL_ALIST";
	} elseif { $numeric == "389" } {
		return "RPL_ENDOFALIST";
	} elseif { $numeric == "391" } {
		return "RPL_TIME";
	} elseif { $numeric == "391" } {
		return "RPL_TIME";
	} elseif { $numeric == "391" } {
		return "RPL_TIME";
	} elseif { $numeric == "391" } {
		return "RPL_TIME";
	} elseif { $numeric == "392" } {
		return "RPL_USERSSTART";
	} elseif { $numeric == "393" } {
		return "RPL_USERS";
	} elseif { $numeric == "394" } {
		return "RPL_ENDOFUSERS";
	} elseif { $numeric == "395" } {
		return "RPL_NOUSERS";
	} elseif { $numeric == "396" } {
		return "RPL_HOSTHIDDEN";
	} elseif { $numeric == "400" } {
		return "ERR_UNKNOWNERROR";
	} elseif { $numeric == "401" } {
		return "ERR_NOSUCHNICK";
	} elseif { $numeric == "402" } {
		return "ERR_NOSUCHSERVER";
	} elseif { $numeric == "403" } {
		return "ERR_NOSUCHCHANNEL";
	} elseif { $numeric == "404" } {
		return "ERR_CANNOTSENDTOCHAN";
	} elseif { $numeric == "405" } {
		return "ERR_TOOMANYCHANNELS";
	} elseif { $numeric == "406" } {
		return "ERR_WASNOSUCHNICK";
	} elseif { $numeric == "407" } {
		return "ERR_TOOMANYTARGETS";
	} elseif { $numeric == "408" } {
		return "ERR_NOSUCHSERVICE";
	} elseif { $numeric == "408" } {
		return "ERR_NOCOLORSONCHAN";
	} elseif { $numeric == "409" } {
		return "ERR_NOORIGIN";
	} elseif { $numeric == "411" } {
		return "ERR_NORECIPIENT";
	} elseif { $numeric == "412" } {
		return "ERR_NOTEXTTOSEND";
	} elseif { $numeric == "413" } {
		return "ERR_NOTOPLEVEL";
	} elseif { $numeric == "414" } {
		return "ERR_WILDTOPLEVEL";
	} elseif { $numeric == "415" } {
		return "ERR_BADMASK";
	} elseif { $numeric == "416" } {
		return "ERR_TOOMANYMATCHES";
	} elseif { $numeric == "416" } {
		return "ERR_QUERYTOOLONG";
	} elseif { $numeric == "419" } {
		return "ERR_LENGTHTRUNCATED";
	} elseif { $numeric == "421" } {
		return "ERR_UNKNOWNCOMMAND";
	} elseif { $numeric == "422" } {
		return "ERR_NOMOTD";
	} elseif { $numeric == "423" } {
		return "ERR_NOADMININFO";
	} elseif { $numeric == "424" } {
		return "ERR_FILEERROR";
	} elseif { $numeric == "425" } {
		return "ERR_NOOPERMOTD";
	} elseif { $numeric == "429" } {
		return "ERR_TOOMANYAWAY";
	} elseif { $numeric == "430" } {
		return "ERR_EVENTNICKCHANGE";
	} elseif { $numeric == "431" } {
		return "ERR_NONICKNAMEGIVEN";
	} elseif { $numeric == "432" } {
		return "ERR_ERRONEUSNICKNAME";
	} elseif { $numeric == "433" } {
		return "ERR_NICKNAMEINUSE";
	} elseif { $numeric == "434" } {
		return "ERR_SERVICENAMEINUSE";
	} elseif { $numeric == "434" } {
		return "ERR_NORULES";
	} elseif { $numeric == "435" } {
		return "ERR_SERVICECONFUSED";
	} elseif { $numeric == "435" } {
		return "ERR_BANONCHAN";
	} elseif { $numeric == "436" } {
		return "ERR_NICKCOLLISION";
	} elseif { $numeric == "437" } {
		return "ERR_UNAVAILRESOURCE";
	} elseif { $numeric == "437" } {
		return "ERR_BANNICKCHANGE";
	} elseif { $numeric == "438" } {
		return "ERR_NICKTOOFAST";
	} elseif { $numeric == "438" } {
		return "ERR_DEAD";
	} elseif { $numeric == "439" } {
		return "ERR_TARGETTOOFAST";
	} elseif { $numeric == "440" } {
		return "ERR_SERVICESDOWN";
	} elseif { $numeric == "441" } {
		return "ERR_USERNOTINCHANNEL";
	} elseif { $numeric == "442" } {
		return "ERR_NOTONCHANNEL";
	} elseif { $numeric == "443" } {
		return "ERR_USERONCHANNEL";
	} elseif { $numeric == "444" } {
		return "ERR_NOLOGIN";
	} elseif { $numeric == "445" } {
		return "ERR_SUMMONDISABLED";
	} elseif { $numeric == "446" } {
		return "ERR_USERSDISABLED";
	} elseif { $numeric == "447" } {
		return "ERR_NONICKCHANGE";
	} elseif { $numeric == "449" } {
		return "ERR_NOTIMPLEMENTED";
	} elseif { $numeric == "451" } {
		return "ERR_NOTREGISTERED";
	} elseif { $numeric == "452" } {
		return "ERR_IDCOLLISION";
	} elseif { $numeric == "453" } {
		return "ERR_NICKLOST";
	} elseif { $numeric == "455" } {
		return "ERR_HOSTILENAME";
	} elseif { $numeric == "456" } {
		return "ERR_ACCEPTFULL";
	} elseif { $numeric == "457" } {
		return "ERR_ACCEPTEXIST";
	} elseif { $numeric == "458" } {
		return "ERR_ACCEPTNOT";
	} elseif { $numeric == "459" } {
		return "ERR_NOHIDING";
	} elseif { $numeric == "460" } {
		return "ERR_NOTFORHALFOPS";
	} elseif { $numeric == "461" } {
		return "ERR_NEEDMOREPARAMS";
	} elseif { $numeric == "462" } {
		return "ERR_ALREADYREGISTERED";
	} elseif { $numeric == "463" } {
		return "ERR_NOPERMFORHOST";
	} elseif { $numeric == "464" } {
		return "ERR_PASSWDMISMATCH";
	} elseif { $numeric == "465" } {
		return "ERR_YOUREBANNEDCREEP";
	} elseif { $numeric == "466" } {
		return "ERR_YOUWILLBEBANNED";
	} elseif { $numeric == "467" } {
		return "ERR_KEYSET";
	} elseif { $numeric == "468" } {
		return "ERR_INVALIDUSERNAME";
	} elseif { $numeric == "468" } {
		return "ERR_ONLYSERVERSCANCHANGE";
	} elseif { $numeric == "469" } {
		return "ERR_LINKSET";
	} elseif { $numeric == "470" } {
		return "ERR_LINKCHANNEL";
	} elseif { $numeric == "470" } {
		return "ERR_KICKEDFROMCHAN";
	} elseif { $numeric == "471" } {
		return "ERR_CHANNELISFULL";
	} elseif { $numeric == "472" } {
		return "ERR_UNKNOWNMODE";
	} elseif { $numeric == "473" } {
		return "ERR_INVITEONLYCHAN";
	} elseif { $numeric == "474" } {
		return "ERR_BANNEDFROMCHAN";
	} elseif { $numeric == "475" } {
		return "ERR_BADCHANNELKEY";
	} elseif { $numeric == "476" } {
		return "ERR_BADCHANMASK";
	} elseif { $numeric == "477" } {
		return "ERR_NOCHANMODES";
	} elseif { $numeric == "477" } {
		return "ERR_NEEDREGGEDNICK";
	} elseif { $numeric == "478" } {
		return "ERR_BANLISTFULL";
	} elseif { $numeric == "479" } {
		return "ERR_BADCHANNAME";
	} elseif { $numeric == "479" } {
		return "ERR_LINKFAIL";
	} elseif { $numeric == "480" } {
		return "ERR_NOULINE";
	} elseif { $numeric == "480" } {
		return "ERR_CANNOTKNOCK";
	} elseif { $numeric == "481" } {
		return "ERR_NOPRIVILEGES";
	} elseif { $numeric == "482" } {
		return "ERR_CHANOPRIVSNEEDED";
	} elseif { $numeric == "483" } {
		return "ERR_CANTKILLSERVER";
	} elseif { $numeric == "484" } {
		return "ERR_RESTRICTED";
	} elseif { $numeric == "484" } {
		return "ERR_ISCHANSERVICE";
	} elseif { $numeric == "484" } {
		return "ERR_DESYNC";
	} elseif { $numeric == "484" } {
		return "ERR_ATTACKDENY";
	} elseif { $numeric == "485" } {
		return "ERR_UNIQOPRIVSNEEDED";
	} elseif { $numeric == "485" } {
		return "ERR_KILLDENY";
	} elseif { $numeric == "485" } {
		return "ERR_CANTKICKADMIN";
	} elseif { $numeric == "485" } {
		return "ERR_ISREALSERVICE";
	} elseif { $numeric == "486" } {
		return "ERR_NONONREG";
	} elseif { $numeric == "486" } {
		return "ERR_HTMDISABLED";
	} elseif { $numeric == "486" } {
		return "ERR_ACCOUNTONLY";
	} elseif { $numeric == "487" } {
		return "ERR_CHANTOORECENT";
	} elseif { $numeric == "487" } {
		return "ERR_MSGSERVICES";
	} elseif { $numeric == "488" } {
		return "ERR_TSLESSCHAN";
	} elseif { $numeric == "489" } {
		return "ERR_VOICENEEDED";
	} elseif { $numeric == "489" } {
		return "ERR_SECUREONLYCHAN";
	} elseif { $numeric == "491" } {
		return "ERR_NOOPERHOST";
	} elseif { $numeric == "492" } {
		return "ERR_NOSERVICEHOST";
	} elseif { $numeric == "493" } {
		return "ERR_NOFEATURE";
	} elseif { $numeric == "494" } {
		return "ERR_BADFEATURE";
	} elseif { $numeric == "495" } {
		return "ERR_BADLOGTYPE";
	} elseif { $numeric == "496" } {
		return "ERR_BADLOGSYS";
	} elseif { $numeric == "497" } {
		return "ERR_BADLOGVALUE";
	} elseif { $numeric == "498" } {
		return "ERR_ISOPERLCHAN";
	} elseif { $numeric == "499" } {
		return "ERR_CHANOWNPRIVNEEDED";
	} elseif { $numeric == "501" } {
		return "ERR_UMODEUNKNOWNFLAG";
	} elseif { $numeric == "502" } {
		return "ERR_USERSDONTMATCH";
	} elseif { $numeric == "503" } {
		return "ERR_GHOSTEDCLIENT";
	} elseif { $numeric == "503" } {
		return "ERR_VWORLDWARN";
	} elseif { $numeric == "504" } {
		return "ERR_USERNOTONSERV";
	} elseif { $numeric == "511" } {
		return "ERR_SILELISTFULL";
	} elseif { $numeric == "512" } {
		return "ERR_TOOMANYWATCH";
	} elseif { $numeric == "513" } {
		return "ERR_BADPING";
	} elseif { $numeric == "514" } {
		return "ERR_INVALID_ERROR";
	} elseif { $numeric == "514" } {
		return "ERR_TOOMANYDCC";
	} elseif { $numeric == "515" } {
		return "ERR_BADEXPIRE";
	} elseif { $numeric == "516" } {
		return "ERR_DONTCHEAT";
	} elseif { $numeric == "517" } {
		return "ERR_DISABLED";
	} elseif { $numeric == "518" } {
		return "ERR_NOINVITE";
	} elseif { $numeric == "518" } {
		return "ERR_LONGMASK";
	} elseif { $numeric == "519" } {
		return "ERR_ADMONLY";
	} elseif { $numeric == "519" } {
		return "ERR_TOOMANYUSERS";
	} elseif { $numeric == "520" } {
		return "ERR_OPERONLY";
	} elseif { $numeric == "520" } {
		return "ERR_MASKTOOWIDE";
	} elseif { $numeric == "520" } {
		return "ERR_WHOTRUNC";
	} elseif { $numeric == "521" } {
		return "ERR_LISTSYNTAX";
	} elseif { $numeric == "522" } {
		return "ERR_WHOSYNTAX";
	} elseif { $numeric == "523" } {
		return "ERR_WHOLIMEXCEED";
	} elseif { $numeric == "524" } {
		return "ERR_QUARANTINED";
	} elseif { $numeric == "524" } {
		return "ERR_OPERSPVERIFY";
	} elseif { $numeric == "525" } {
		return "ERR_REMOTEPFX";
	} elseif { $numeric == "526" } {
		return "ERR_PFXUNROUTABLE";
	} elseif { $numeric == "550" } {
		return "ERR_BADHOSTMASK";
	} elseif { $numeric == "551" } {
		return "ERR_HOSTUNAVAIL";
	} elseif { $numeric == "552" } {
		return "ERR_USINGSLINE";
	} elseif { $numeric == "553" } {
		return "ERR_STATSSLINE";
	} elseif { $numeric == "600" } {
		return "RPL_LOGON";
	} elseif { $numeric == "601" } {
		return "RPL_LOGOFF";
	} elseif { $numeric == "602" } {
		return "RPL_WATCHOFF";
	} elseif { $numeric == "603" } {
		return "RPL_WATCHSTAT";
	} elseif { $numeric == "604" } {
		return "RPL_NOWON";
	} elseif { $numeric == "605" } {
		return "RPL_NOWOFF";
	} elseif { $numeric == "606" } {
		return "RPL_WATCHLIST";
	} elseif { $numeric == "607" } {
		return "RPL_ENDOFWATCHLIST";
	} elseif { $numeric == "608" } {
		return "RPL_WATCHCLEAR";
	} elseif { $numeric == "610" } {
		return "RPL_MAPMORE";
	} elseif { $numeric == "610" } {
		return "RPL_ISOPER";
	} elseif { $numeric == "611" } {
		return "RPL_ISLOCOP";
	} elseif { $numeric == "612" } {
		return "RPL_ISNOTOPER";
	} elseif { $numeric == "613" } {
		return "RPL_ENDOFISOPER";
	} elseif { $numeric == "615" } {
		return "RPL_MAPMORE";
	} elseif { $numeric == "615" } {
		return "RPL_WHOISMODES";
	} elseif { $numeric == "616" } {
		return "RPL_WHOISHOST";
	} elseif { $numeric == "617" } {
		return "RPL_DCCSTATUS";
	} elseif { $numeric == "617" } {
		return "RPL_WHOISBOT";
	} elseif { $numeric == "618" } {
		return "RPL_DCCLIST";
	} elseif { $numeric == "619" } {
		return "RPL_ENDOFDCCLIST";
	} elseif { $numeric == "619" } {
		return "RPL_WHOWASHOST";
	} elseif { $numeric == "620" } {
		return "RPL_DCCINFO";
	} elseif { $numeric == "620" } {
		return "RPL_RULESSTART";
	} elseif { $numeric == "621" } {
		return "RPL_RULES";
	} elseif { $numeric == "622" } {
		return "RPL_ENDOFRULES";
	} elseif { $numeric == "623" } {
		return "RPL_MAPMORE";
	} elseif { $numeric == "624" } {
		return "RPL_OMOTDSTART";
	} elseif { $numeric == "625" } {
		return "RPL_OMOTD";
	} elseif { $numeric == "626" } {
		return "RPL_ENDOFO";
	} elseif { $numeric == "630" } {
		return "RPL_SETTINGS";
	} elseif { $numeric == "631" } {
		return "RPL_ENDOFSETTINGS";
	} elseif { $numeric == "640" } {
		return "RPL_DUMPING";
	} elseif { $numeric == "641" } {
		return "RPL_DUMPRPL";
	} elseif { $numeric == "642" } {
		return "RPL_EODUMP";
	} elseif { $numeric == "660" } {
		return "RPL_TRACEROUTE_HOP";
	} elseif { $numeric == "661" } {
		return "RPL_TRACEROUTE_START";
	} elseif { $numeric == "662" } {
		return "RPL_MODECHANGEWARN";
	} elseif { $numeric == "663" } {
		return "RPL_CHANREDIR";
	} elseif { $numeric == "664" } {
		return "RPL_SERVMODEIS";
	} elseif { $numeric == "665" } {
		return "RPL_OTHERUMODEIS";
	} elseif { $numeric == "666" } {
		return "RPL_ENDOF_GENERIC";
	} elseif { $numeric == "670" } {
		return "RPL_WHOWASDETAILS";
	} elseif { $numeric == "671" } {
		return "RPL_WHOISSECURE";
	} elseif { $numeric == "672" } {
		return "RPL_UNKNOWNMODES";
	} elseif { $numeric == "673" } {
		return "RPL_CANNOTSETMODES";
	} elseif { $numeric == "678" } {
		return "RPL_LUSERSTAFF";
	} elseif { $numeric == "679" } {
		return "RPL_TIMEONSERVERIS";
	} elseif { $numeric == "682" } {
		return "RPL_NETWORKS";
	} elseif { $numeric == "687" } {
		return "RPL_YOURLANGUAGEIS";
	} elseif { $numeric == "688" } {
		return "RPL_LANGUAGE";
	} elseif { $numeric == "689" } {
		return "RPL_WHOISSTAFF";
	} elseif { $numeric == "690" } {
		return "RPL_WHOISLANGUAGE";
	} elseif { $numeric == "702" } {
		return "RPL_MODLIST";
	} elseif { $numeric == "703" } {
		return "RPL_ENDOFMODLIST";
	} elseif { $numeric == "704" } {
		return "RPL_HELPSTART";
	} elseif { $numeric == "705" } {
		return "RPL_HELPTXT";
	} elseif { $numeric == "706" } {
		return "RPL_ENDOFHELP";
	} elseif { $numeric == "708" } {
		return "RPL_ETRACEFULL";
	} elseif { $numeric == "709" } {
		return "RPL_ETRACE";
	} elseif { $numeric == "710" } {
		return "RPL_KNOCK";
	} elseif { $numeric == "711" } {
		return "RPL_KNOCKDLVR";
	} elseif { $numeric == "712" } {
		return "ERR_TOOMANYKNOCK";
	} elseif { $numeric == "713" } {
		return "ERR_CHANOPEN";
	} elseif { $numeric == "714" } {
		return "ERR_KNOCKONCHAN";
	} elseif { $numeric == "715" } {
		return "ERR_KNOCKDISABLED";
	} elseif { $numeric == "716" } {
		return "RPL_TARGUMODEG";
	} elseif { $numeric == "717" } {
		return "RPL_TARGNOTIFY";
	} elseif { $numeric == "718" } {
		return "RPL_UMODEGMSG";
	} elseif { $numeric == "720" } {
		return "RPL_OMOTDSTART";
	} elseif { $numeric == "721" } {
		return "RPL_OMOTD";
	} elseif { $numeric == "722" } {
		return "RPL_ENDOFOMOTD";
	} elseif { $numeric == "723" } {
		return "ERR_NOPRIVS";
	} elseif { $numeric == "724" } {
		return "RPL_TESTMARK";
	} elseif { $numeric == "725" } {
		return "RPL_TESTLINE";
	} elseif { $numeric == "726" } {
		return "RPL_NOTESTLINE";
	} elseif { $numeric == "771" } {
		return "RPL_XINFO";
	} elseif { $numeric == "773" } {
		return "RPL_XINFOSTART";
	} elseif { $numeric == "774" } {
		return "RPL_XINFOEND";
	} elseif { $numeric == "972" } {
		return "ERR_CANNOTDOCOMMAND";
	} elseif { $numeric == "973" } {
		return "ERR_CANNOTCHANGEUMODE";
	} elseif { $numeric == "974" } {
		return "ERR_CANNOTCHANGECHANMODE";
	} elseif { $numeric == "975" } {
		return "ERR_CANNOTCHANGESERVERMODE";
	} elseif { $numeric == "976" } {
		return "ERR_CANNOTSENDTONICK";
	} elseif { $numeric == "977" } {
		return "ERR_UNKNOWNSERVERMODE";
	} elseif { $numeric == "979" } {
		return "ERR_SERVERMODELOCK";
	} elseif { $numeric == "980" } {
		return "ERR_BADCHARENCODING";
	} elseif { $numeric == "981" } {
		return "ERR_TOOMANYLANGUAGES";
	} elseif { $numeric == "982" } {
		return "ERR_NOLANGUAGE";
	} elseif { $numeric == "983" } {
		return "ERR_TEXTTOOSHORT";
	} elseif { $numeric == "999" } {
		return "ERR_NUMERIC_ERR";
	} else { return $numeric }
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
		
		proc numname { } {
			variable linedata
			return $linedata(numname)
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
			set linedata(who)			[string trim [lindex $header 0]];
			set linedata(action)		[string trim [lindex $header 1]];
			set linedata(target)		[string trim [lindex $header 2]];
			set linedata(additional)	[string trim [lrange $header 3 end]];
			set linedata(numname)		[::IRCC::num2name [lindex $header 1]];
			if { [info exists dispatch($linedata(action))] } {
				eval $dispatch($linedata(action))
			} elseif { [info exists dispatch($linedata(numname))] } {
				eval $dispatch($linedata(numname))
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
