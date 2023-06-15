# irc.tcl --
#
#  irc implementation for Tcl.
#
# Copyright (c) 2001-2003 by David N. Welton <davidw@dedasys.com>.
# This code may be distributed under the same terms as Tcl.

# -------------------------------------------------------------------------

package require Tcl 8.6

# -------------------------------------------------------------------------

namespace eval ::IRCC {
  # counter used to differentiate connections
  variable conn                  0
  variable config
  variable pkg_vers             0.0.1
  variable pkg_vers_min_need_tcl  8.6
  variable pkg_vers_min_need_tls  1.7.16
  variable irctclfile           [info script]
  array set config  {
    debug                       0
    logger                      0
    name                        ""
  }
}

# ::IRCC::config --
#
# Set global configuration options.
#
# Arguments:
#
# key  name of the configuration option to change.
#
# value  value of the configuration option.

proc ::IRCC::config { args } {
  variable config
  if { [llength $args] == 0 } {
    return [array get config]
  } elseif { [llength $args] == 1 } {
    set key                     [lindex $args 0]
    return $config($key)
  } elseif { [llength $args] > 2 } {
    error "wrong # args: should be \"config key ?val?\""
  }
  set key                       [lindex $args 0]
  set value                     [lindex $args 1]
  foreach ns [namespace children] {
    if {
      [info exists config($key)]                                               \
        && [info exists ${ns}::config($key)]                                   \
        && [set ${ns}::config($key)] == $config($key)
    } {
      ${ns}::cmd-config $key $value
    }
  }
  set config($key)  $value
}

# ::IRCC::connections --
#
# Return a list of handles to all existing connections

proc ::IRCC::connections { } {
  set r  {}
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
  set oldconn  $conn
  namespace eval :: {
    source [set ::IRCC::irctclfile]
  }
  foreach ns [namespace children] {
    foreach var {sock logger host port} {
      set $var  [set ${ns}::$var]
    }
    array set dispatch  [array get ${ns}::dispatch]
    array set config  [array get ${ns}::config]
    # make sure our new connection uses the same namespace
    set conn      [string range $ns 10 end]
    ::IRCC::connection
    foreach var {sock logger host port} {
      set ${ns}::$var    [set $var]
    }
    array set ${ns}::dispatch  [array get dispatch]
    array set ${ns}::config    [array get config]
  }
  set conn  $oldconn
}
proc num2name {numeric} {
  array set numeric_mapping {
    "001" "RPL_WELCOME"
    "002" "RPL_YOURHOST"
    "003" "RPL_CREATED"
    "004" "RPL_MYINFO"
    "004" "RPL_MYINFO"
    "005" "RPL_BOUNCE"
    "005" "RPL_ISUPPORT"
    "006" "RPL_MAP"
    "007" "RPL_MAPEND"
    "008" "RPL_SNOMASK"
    "009" "RPL_STATMEMTOT"
    "010" "RPL_BOUNCE"
    "010" "RPL_STATMEM"
    "014" "RPL_YOURCOOKIE"
    "015" "RPL_MAP"
    "016" "RPL_MAPMORE"
    "017" "RPL_MAPEND"
    "042" "RPL_YOURID"
    "043" "RPL_SAVENICK"
    "050" "RPL_ATTEMPTINGJUNC"
    "051" "RPL_ATTEMPTINGREROUTE"
    "200" "RPL_TRACELINK"
    "201" "RPL_TRACECONNECTING"
    "202" "RPL_TRACEHANDSHAKE"
    "203" "RPL_TRACEUNKNOWN"
    "204" "RPL_TRACEOPERATOR"
    "205" "RPL_TRACEUSER"
    "206" "RPL_TRACESERVER"
    "207" "RPL_TRACESERVICE"
    "208" "RPL_TRACENEWTYPE"
    "209" "RPL_TRACECLASS"
    "210" "RPL_TRACERECONNECT"
    "210" "RPL_STATS"
    "211" "RPL_STATSLINKINFO"
    "212" "RPL_STATSCOMMANDS"
    "213" "RPL_STATSCLINE"
    "214" "RPL_STATSNLINE"
    "215" "RPL_STATSILINE"
    "216" "RPL_STATSKLINE"
    "217" "RPL_STATSQLINE"
    "217" "RPL_STATSPLINE"
    "218" "RPL_STATSYLINE"
    "219" "RPL_ENDOFSTATS"
    "220" "RPL_STATSPLINE"
    "220" "RPL_STATSBLINE"
    "221" "RPL_UMODEIS"
    "222" "RPL_MODLIST"
    "222" "RPL_SQLINE_NICK"
    "222" "RPL_STATSBLINE"
    "223" "RPL_STATSELINE"
    "223" "RPL_STATSGLINE"
    "224" "RPL_STATSFLINE"
    "224" "RPL_STATSTLINE"
    "225" "RPL_STATSDLINE"
    "225" "RPL_STATSZLINE"
    "225" "RPL_STATSELINE"
    "226" "RPL_STATSCOUNT"
    "226" "RPL_STATSNLINE"
    "227" "RPL_STATSGLINE"
    "227" "RPL_STATSVLINE"
    "228" "RPL_STATSQLINE"
    "231" "RPL_SERVICEINFO"
    "232" "RPL_ENDOFSERVICES"
    "232" "RPL_RULES"
    "233" "RPL_SERVICE"
    "234" "RPL_SERVLIST"
    "235" "RPL_SERVLISTEND"
    "236" "RPL_STATSVERBOSE"
    "237" "RPL_STATSENGINE"
    "238" "RPL_STATSFLINE"
    "239" "RPL_STATSIAUTH"
    "240" "RPL_STATSVLINE"
    "240" "RPL_STATSXLINE"
    "241" "RPL_STATSLLINE"
    "242" "RPL_STATSUPTIME"
    "243" "RPL_STATSOLINE"
    "244" "RPL_STATSHLINE"
    "245" "RPL_STATSSLINE"
    "246" "RPL_STATSPING"
    "246" "RPL_STATSTLINE"
    "246" "RPL_STATSULINE"
    "247" "RPL_STATSBLINE"
    "247" "RPL_STATSXLINE"
    "247" "RPL_STATSGLINE"
    "248" "RPL_STATSULINE"
    "248" "RPL_STATSDEFINE"
    "249" "RPL_STATSULINE"
    "249" "RPL_STATSDEBUG"
    "250" "RPL_STATSDLINE"
    "250" "RPL_STATSCONN"
    "251" "RPL_LUSERCLIENT"
    "252" "RPL_LUSEROP"
    "253" "RPL_LUSERUNKNOWN"
    "254" "RPL_LUSERCHANNELS"
    "255" "RPL_LUSERME"
    "256" "RPL_ADMINME"
    "257" "RPL_ADMINLOC1"
    "258" "RPL_ADMINLOC2"
    "259" "RPL_ADMINEMAIL"
    "261" "RPL_TRACELOG"
    "262" "RPL_TRACEPING"
    "262" "RPL_TRACEEND"
    "263" "RPL_TRYAGAIN"
    "265" "RPL_LOCALUSERS"
    "266" "RPL_GLOBALUSERS"
    "267" "RPL_START_NETSTAT"
    "268" "RPL_NETSTAT"
    "269" "RPL_END_NETSTAT"
    "270" "RPL_PRIVS"
    "271" "RPL_SILELIST"
    "272" "RPL_ENDOFSILELIST"
    "273" "RPL_NOTIFY"
    "274" "RPL_ENDNOTIFY"
    "274" "RPL_STATSDELTA"
    "275" "RPL_STATSDLINE"
    "276" "RPL_VCHANEXIST"
    "277" "RPL_VCHANLIST"
    "278" "RPL_VCHANHELP"
    "280" "RPL_GLIST"
    "281" "RPL_ENDOFGLIST"
    "281" "RPL_ACCEPTLIST"
    "282" "RPL_ENDOFACCEPT"
    "282" "RPL_JUPELIST"
    "283" "RPL_ALIST"
    "283" "RPL_ENDOFJUPELIST"
    "284" "RPL_ENDOFALIST"
    "284" "RPL_FEATURE"
    "285" "RPL_GLIST_HASH"
    "285" "RPL_CHANINFO_HANDLE"
    "285" "RPL_NEWHOSTIS"
    "286" "RPL_CHANINFO_USERS"
    "286" "RPL_CHKHEAD"
    "287" "RPL_CHANINFO_CHOPS"
    "287" "RPL_CHANUSER"
    "288" "RPL_CHANINFO_VOICES"
    "288" "RPL_PATCHHEAD"
    "289" "RPL_CHANINFO_AWAY"
    "289" "RPL_PATCHCON"
    "290" "RPL_CHANINFO_OPERS"
    "290" "RPL_HELPHDR"
    "290" "RPL_DATASTR"
    "291" "RPL_CHANINFO_BANNED"
    "291" "RPL_HELPOP"
    "291" "RPL_ENDOFCHECK"
    "292" "RPL_CHANINFO_BANS"
    "292" "RPL_HELPTLR"
    "293" "RPL_CHANINFO_INVITE"
    "293" "RPL_HELPHLP"
    "294" "RPL_CHANINFO_INVITES"
    "294" "RPL_HELPFWD"
    "295" "RPL_CHANINFO_KICK"
    "295" "RPL_HELPIGN"
    "296" "RPL_CHANINFO_KICKS"
    "299" "RPL_END_CHANINFO"
    "300" "RPL_NONE"
    "301" "RPL_AWAY"
    "301" "RPL_AWAY"
    "302" "RPL_USERHOST"
    "303" "RPL_ISON"
    "304" "RPL_TEXT"
    "305" "RPL_UNAWAY"
    "306" "RPL_NOWAWAY"
    "307" "RPL_USERIP"
    "307" "RPL_WHOISREGNICK"
    "307" "RPL_SUSERHOST"
    "308" "RPL_NOTIFYACTION"
    "308" "RPL_WHOISADMIN"
    "308" "RPL_RULESSTART"
    "309" "RPL_NICKTRACE"
    "309" "RPL_WHOISSADMIN"
    "309" "RPL_ENDOFRULES"
    "309" "RPL_WHOISHELPER"
    "310" "RPL_WHOISSVCMSG"
    "310" "RPL_WHOISHELPOP"
    "310" "RPL_WHOISSERVICE"
    "311" "RPL_WHOISUSER"
    "312" "RPL_WHOISSERVER"
    "313" "RPL_WHOISOPERATOR"
    "314" "RPL_WHOWASUSER"
    "315" "RPL_ENDOFWHO"
    "316" "RPL_WHOISCHANOP"
    "317" "RPL_WHOISIDLE"
    "318" "RPL_ENDOFWHOIS"
    "319" "RPL_WHOISCHANNELS"
    "320" "RPL_WHOISVIRT"
    "320" "RPL_WHOIS_HIDDEN"
    "320" "RPL_WHOISSPECIAL"
    "321" "RPL_LISTSTART"
    "322" "RPL_LIST"
    "323" "RPL_LISTEND"
    "324" "RPL_CHANNELMODEIS"
    "325" "RPL_UNIQOPIS"
    "325" "RPL_CHANNELPASSIS"
    "326" "RPL_NOCHANPASS"
    "327" "RPL_CHPASSUNKNOWN"
    "328" "RPL_CHANNEL_URL"
    "329" "RPL_CREATIONTIME"
    "330" "RPL_WHOWAS_TIME"
    "330" "RPL_WHOISACCOUNT"
    "331" "RPL_NOTOPIC"
    "332" "RPL_TOPIC"
    "333" "RPL_TOPICWHOTIME"
    "334" "RPL_LISTUSAGE"
    "334" "RPL_COMMANDSYNTAX"
    "334" "RPL_LISTSYNTAX"
    "335" "RPL_WHOISBOT"
    "338" "RPL_CHANPASSOK"
    "338" "RPL_WHOISACTUALLY"
    "339" "RPL_BADCHANPASS"
    "340" "RPL_USERIP"
    "341" "RPL_INVITING"
    "342" "RPL_SUMMONING"
    "345" "RPL_INVITED"
    "346" "RPL_INVITELIST"
    "347" "RPL_ENDOFINVITELIST"
    "348" "RPL_EXCEPTLIST"
    "349" "RPL_ENDOFEXCEPTLIST"
    "351" "RPL_VERSION"
    "352" "RPL_WHOREPLY"
    "353" "RPL_NAMREPLY"
    "354" "RPL_WHOSPCRPL"
    "355" "RPL_NAMREPLY_"
    "357" "RPL_MAP"
    "358" "RPL_MAPMORE"
    "359" "RPL_MAPEND"
    "361" "RPL_KILLDONE"
    "362" "RPL_CLOSING"
    "363" "RPL_CLOSEEND"
    "364" "RPL_LINKS"
    "365" "RPL_ENDOFLINKS"
    "366" "RPL_ENDOFNAMES"
    "367" "RPL_BANLIST"
    "368" "RPL_ENDOFBANLIST"
    "369" "RPL_ENDOFWHOWAS"
    "371" "RPL_INFO"
    "372" "RPL_MOTD"
    "373" "RPL_INFOSTART"
    "374" "RPL_ENDOFINFO"
    "375" "RPL_MOTDSTART"
    "376" "RPL_ENDOFMOTD"
    "377" "RPL_KICKEXPIRED"
    "377" "RPL_SPAM"
    "378" "RPL_BANEXPIRED"
    "378" "RPL_WHOISHOST"
    "378" "RPL_MOTD"
    "379" "RPL_KICKLINKED"
    "379" "RPL_WHOISMODES"
    "380" "RPL_BANLINKED"
    "380" "RPL_YOURHELPER"
    "381" "RPL_YOUREOPER"
    "382" "RPL_REHASHING"
    "383" "RPL_YOURESERVICE"
    "384" "RPL_MYPORTIS"
    "385" "RPL_NOTOPERANYMORE"
    "386" "RPL_QLIST"
    "386" "RPL_IRCOPS"
    "387" "RPL_ENDOFQLIST"
    "387" "RPL_ENDOFIRCOPS"
    "388" "RPL_ALIST"
    "389" "RPL_ENDOFALIST"
    "391" "RPL_TIME"
    "391" "RPL_TIME"
    "391" "RPL_TIME"
    "391" "RPL_TIME"
    "392" "RPL_USERSSTART"
    "393" "RPL_USERS"
    "394" "RPL_ENDOFUSERS"
    "395" "RPL_NOUSERS"
    "396" "RPL_HOSTHIDDEN"
    "400" "ERR_UNKNOWNERROR"
    "401" "ERR_NOSUCHNICK"
    "402" "ERR_NOSUCHSERVER"
    "403" "ERR_NOSUCHCHANNEL"
    "404" "ERR_CANNOTSENDTOCHAN"
    "405" "ERR_TOOMANYCHANNELS"
    "406" "ERR_WASNOSUCHNICK"
    "407" "ERR_TOOMANYTARGETS"
    "408" "ERR_NOSUCHSERVICE"
    "408" "ERR_NOCOLORSONCHAN"
    "409" "ERR_NOORIGIN"
    "411" "ERR_NORECIPIENT"
    "412" "ERR_NOTEXTTOSEND"
    "413" "ERR_NOTOPLEVEL"
    "414" "ERR_WILDTOPLEVEL"
    "415" "ERR_BADMASK"
    "416" "ERR_TOOMANYMATCHES"
    "416" "ERR_QUERYTOOLONG"
    "419" "ERR_LENGTHTRUNCATED"
    "421" "ERR_UNKNOWNCOMMAND"
    "422" "ERR_NOMOTD"
    "423" "ERR_NOADMININFO"
    "424" "ERR_FILEERROR"
    "425" "ERR_NOOPERMOTD"
    "429" "ERR_TOOMANYAWAY"
    "430" "ERR_EVENTNICKCHANGE"
    "431" "ERR_NONICKNAMEGIVEN"
    "432" "ERR_ERRONEUSNICKNAME"
    "433" "ERR_NICKNAMEINUSE"
    "434" "ERR_SERVICENAMEINUSE"
    "434" "ERR_NORULES"
    "435" "ERR_SERVICECONFUSED"
    "435" "ERR_BANONCHAN"
    "436" "ERR_NICKCOLLISION"
    "437" "ERR_UNAVAILRESOURCE"
    "437" "ERR_BANNICKCHANGE"
    "438" "ERR_NICKTOOFAST"
    "438" "ERR_DEAD"
    "439" "ERR_TARGETTOOFAST"
    "440" "ERR_SERVICESDOWN"
    "441" "ERR_USERNOTINCHANNEL"
    "442" "ERR_NOTONCHANNEL"
    "443" "ERR_USERONCHANNEL"
    "444" "ERR_NOLOGIN"
    "445" "ERR_SUMMONDISABLED"
    "446" "ERR_USERSDISABLED"
    "447" "ERR_NONICKCHANGE"
    "449" "ERR_NOTIMPLEMENTED"
    "451" "ERR_NOTREGISTERED"
    "452" "ERR_IDCOLLISION"
    "453" "ERR_NICKLOST"
    "455" "ERR_HOSTILENAME"
    "456" "ERR_ACCEPTFULL"
    "457" "ERR_ACCEPTEXIST"
    "458" "ERR_ACCEPTNOT"
    "459" "ERR_NOHIDING"
    "460" "ERR_NOTFORHALFOPS"
    "461" "ERR_NEEDMOREPARAMS"
    "462" "ERR_ALREADYREGISTERED"
    "463" "ERR_NOPERMFORHOST"
    "464" "ERR_PASSWDMISMATCH"
    "465" "ERR_YOUREBANNEDCREEP"
    "466" "ERR_YOUWILLBEBANNED"
    "467" "ERR_KEYSET"
    "468" "ERR_INVALIDUSERNAME"
    "468" "ERR_ONLYSERVERSCANCHANGE"
    "469" "ERR_LINKSET"
    "470" "ERR_LINKCHANNEL"
    "470" "ERR_KICKEDFROMCHAN"
    "471" "ERR_CHANNELISFULL"
    "472" "ERR_UNKNOWNMODE"
    "473" "ERR_INVITEONLYCHAN"
    "474" "ERR_BANNEDFROMCHAN"
    "475" "ERR_BADCHANNELKEY"
    "476" "ERR_BADCHANMASK"
    "477" "ERR_NOCHANMODES"
    "477" "ERR_NEEDREGGEDNICK"
    "478" "ERR_BANLISTFULL"
    "479" "ERR_BADCHANNAME"
    "479" "ERR_LINKFAIL"
    "480" "ERR_NOULINE"
    "480" "ERR_CANNOTKNOCK"
    "481" "ERR_NOPRIVILEGES"
    "482" "ERR_CHANOPRIVSNEEDED"
    "483" "ERR_CANTKILLSERVER"
    "484" "ERR_RESTRICTED"
    "484" "ERR_ISCHANSERVICE"
    "484" "ERR_DESYNC"
    "484" "ERR_ATTACKDENY"
    "485" "ERR_UNIQOPRIVSNEEDED"
    "485" "ERR_KILLDENY"
    "485" "ERR_CANTKICKADMIN"
    "485" "ERR_ISREALSERVICE"
    "486" "ERR_NONONREG"
    "486" "ERR_HTMDISABLED"
    "486" "ERR_ACCOUNTONLY"
    "487" "ERR_CHANTOORECENT"
    "487" "ERR_MSGSERVICES"
    "488" "ERR_TSLESSCHAN"
    "489" "ERR_VOICENEEDED"
    "489" "ERR_SECUREONLYCHAN"
    "491" "ERR_NOOPERHOST"
    "492" "ERR_NOSERVICEHOST"
    "493" "ERR_NOFEATURE"
    "494" "ERR_BADFEATURE"
    "495" "ERR_BADLOGTYPE"
    "496" "ERR_BADLOGSYS"
    "497" "ERR_BADLOGVALUE"
    "498" "ERR_ISOPERLCHAN"
    "499" "ERR_CHANOWNPRIVNEEDED"
    "501" "ERR_UMODEUNKNOWNFLAG"
    "502" "ERR_USERSDONTMATCH"
    "503" "ERR_GHOSTEDCLIENT"
    "503" "ERR_VWORLDWARN"
    "504" "ERR_USERNOTONSERV"
    "511" "ERR_SILELISTFULL"
    "512" "ERR_TOOMANYWATCH"
    "513" "ERR_BADPING"
    "514" "ERR_INVALID_ERROR"
    "514" "ERR_TOOMANYDCC"
    "515" "ERR_BADEXPIRE"
    "516" "ERR_DONTCHEAT"
    "517" "ERR_DISABLED"
    "518" "ERR_NOINVITE"
    "518" "ERR_LONGMASK"
    "519" "ERR_ADMONLY"
    "519" "ERR_TOOMANYUSERS"
    "520" "ERR_OPERONLY"
    "520" "ERR_MASKTOOWIDE"
    "520" "ERR_WHOTRUNC"
    "521" "ERR_LISTSYNTAX"
    "522" "ERR_WHOSYNTAX"
    "523" "ERR_WHOLIMEXCEED"
    "524" "ERR_QUARANTINED"
    "524" "ERR_OPERSPVERIFY"
    "525" "ERR_REMOTEPFX"
    "526" "ERR_PFXUNROUTABLE"
    "550" "ERR_BADHOSTMASK"
    "551" "ERR_HOSTUNAVAIL"
    "552" "ERR_USINGSLINE"
    "553" "ERR_STATSSLINE"
    "600" "RPL_LOGON"
    "601" "RPL_LOGOFF"
    "602" "RPL_WATCHOFF"
    "603" "RPL_WATCHSTAT"
    "604" "RPL_NOWON"
    "605" "RPL_NOWOFF"
    "606" "RPL_WATCHLIST"
    "607" "RPL_ENDOFWATCHLIST"
    "608" "RPL_WATCHCLEAR"
    "610" "RPL_MAPMORE"
    "610" "RPL_ISOPER"
    "611" "RPL_ISLOCOP"
    "612" "RPL_ISNOTOPER"
    "613" "RPL_ENDOFISOPER"
    "615" "RPL_MAPMORE"
    "615" "RPL_WHOISMODES"
    "616" "RPL_WHOISHOST"
    "617" "RPL_DCCSTATUS"
    "617" "RPL_WHOISBOT"
    "618" "RPL_DCCLIST"
    "619" "RPL_ENDOFDCCLIST"
    "619" "RPL_WHOWASHOST"
    "620" "RPL_DCCINFO"
    "620" "RPL_RULESSTART"
    "621" "RPL_RULES"
    "622" "RPL_ENDOFRULES"
    "623" "RPL_MAPMORE"
    "624" "RPL_OMOTDSTART"
    "625" "RPL_OMOTD"
    "626" "RPL_ENDOFO"
    "630" "RPL_SETTINGS"
    "631" "RPL_ENDOFSETTINGS"
    "640" "RPL_DUMPING"
    "641" "RPL_DUMPRPL"
    "642" "RPL_EODUMP"
    "660" "RPL_TRACEROUTE_HOP"
    "661" "RPL_TRACEROUTE_START"
    "662" "RPL_MODECHANGEWARN"
    "663" "RPL_CHANREDIR"
    "664" "RPL_SERVMODEIS"
    "665" "RPL_OTHERUMODEIS"
    "666" "RPL_ENDOF_GENERIC"
    "670" "RPL_WHOWASDETAILS"
    "671" "RPL_WHOISSECURE"
    "672" "RPL_UNKNOWNMODES"
    "673" "RPL_CANNOTSETMODES"
    "678" "RPL_LUSERSTAFF"
    "679" "RPL_TIMEONSERVERIS"
    "682" "RPL_NETWORKS"
    "687" "RPL_YOURLANGUAGEIS"
    "688" "RPL_LANGUAGE"
    "689" "RPL_WHOISSTAFF"
    "690" "RPL_WHOISLANGUAGE"
    "702" "RPL_MODLIST"
    "703" "RPL_ENDOFMODLIST"
    "704" "RPL_HELPSTART"
    "705" "RPL_HELPTXT"
    "706" "RPL_ENDOFHELP"
    "708" "RPL_ETRACEFULL"
    "709" "RPL_ETRACE"
    "710" "RPL_KNOCK"
    "711" "RPL_KNOCKDLVR"
    "712" "ERR_TOOMANYKNOCK"
    "713" "ERR_CHANOPEN"
    "714" "ERR_KNOCKONCHAN"
    "715" "ERR_KNOCKDISABLED"
    "716" "RPL_TARGUMODEG"
    "717" "RPL_TARGNOTIFY"
    "718" "RPL_UMODEGMSG"
    "720" "RPL_OMOTDSTART"
    "721" "RPL_OMOTD"
    "722" "RPL_ENDOFOMOTD"
    "723" "ERR_NOPRIVS"
    "724" "RPL_TESTMARK"
    "725" "RPL_TESTLINE"
    "726" "RPL_NOTESTLINE"
    "771" "RPL_XINFO"
    "773" "RPL_XINFOSTART"
    "773" "RPL_LOGGEDIN"
    "774" "RPL_XINFOEND"
    "972" "ERR_CANNOTDOCOMMAND"
    "973" "ERR_CANNOTCHANGEUMODE"
    "974" "ERR_CANNOTCHANGECHANMODE"
    "975" "ERR_CANNOTCHANGESERVERMODE"
    "976" "ERR_CANNOTSENDTONICK"
    "977" "ERR_UNKNOWNSERVERMODE"
    "979" "ERR_SERVERMODELOCK"
    "980" "ERR_BADCHARENCODING"
    "981" "ERR_TOOMANYLANGUAGES"
    "982" "ERR_NOLANGUAGE"
    "983" "ERR_TEXTTOOSHORT"
    "999" "ERR_NUMERIC_ERR";

  }
  if { [info exists numeric_mapping($numeric)] } {
    return $numeric_mapping($numeric)
  } else {
    return $numeric
  }
}

# ::IRCC::connection --
#
# Create an IRC connection namespace and associated commands.

proc ::IRCC::connection { args } {
  variable conn
  variable config

  # Create a unique namespace of the form irc$conn::$host

  set name  [format "%s::IRCC%s" [namespace current] $conn]

  namespace eval $name {
    variable sock
    variable dispatch
    variable linedata
    variable config

    set sock      {}
    array set dispatch  {}
    array set linedata  {}
    array set config  [array get ::IRCC::config]
    if { $config(logger) || $config(debug) } {
      package require logger
      variable logger
      set logger    [logger::init [namespace tail [namespace current]]]
      if { !$config(debug) } { ${logger}::disable debug }
    }
    proc TLSSocketCallBack { level args } {
      set SOCKET_NAME  [lindex $args 0]
      set type    [lindex $args 1]
      set socketid  [lindex $args 2]
      set what    [lrange $args 3 end]
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
        set sock  {}
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
    # key  name of the configuration option to change.
    #
    # value  value (optional) of the configuration option.

    proc cmd-config { args } {
      variable config
      variable logger

      if { [llength $args] == 0 } {
        return [array get config]
      } elseif { [llength $args] == 1 } {
        set key  [lindex $args 0]
        return $config($key)
      } elseif { [llength $args] > 2 } {
        error "wrong # args: should be \"config key ?val?\""
      }
      set key    [lindex $args 0]
      set value  [lindex $args 1]
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
          set logger  [logger::init [namespace tail [namespace current]]]
        } elseif { [info exists logger] } {
          ${logger}::delete
          unset  logger
        }
      }
      set config($key)  $value
    }
    # cmd-getconfig --
    #
    # Return the value of a configuration option.
    #
    # Arguments:
    #
    # key  name of the configuration option to return.
    proc cmd-getconfig { key } {
      variable config
      return $config($key)
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
      if { $key eq "" } {
        ircsend "JOIN $chan"
      } else {
        ircsend "JOIN $chan :$key"
      }
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
      set sock  {}
      return 0
    }

    # Connect --
    # Create the actual tcp connection.
    # http://abcdrfc.free.fr/rfc-vf/rfc1459.html#41
    proc cmd-connect { IRC_HOSTNAME {IRC_PORT +6697} {IRC_PASSWORD ""} } {
      variable sock
      variable host
      variable port

      set host  $IRC_HOSTNAME
      set s_port  $IRC_PORT
      if { [string range $s_port 0 0] == "+" } {
        set secure  1;
        set port  [string range $s_port 1 end]
      } else {
        set secure  0;
        set port  $s_port
      }
      if { $secure == 1 } {
        package require tls $::IRCC::pkg_vers_min_need_tls
        set socket_binary  "::tls::socket -require 0 -request 0 -command \"[namespace current]::TLSSocketCallBack $sock\""
      } else {
        set socket_binary  ::socket
      }
      if { $sock eq "" } {
        set sock  [{*}$socket_binary $host $port]
        fconfigure $sock -translation crlf -buffering line
        fileevent $sock readable [namespace current]::GetEvent
        if { $IRC_PASSWORD != "" } {
          ircsend  "PASS $IRC_PASSWORD"
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

    proc rawline { } {
      variable linedata
      return $linedata(rawline)
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
      array set linedata  {}
      set line      "eof"
      if { [eof $sock] || [catch {gets $sock} line] } {
        close $sock
        set sock  {}
        cmd-log error "Error receiving from network: $line"
        if { [info exists dispatch(EOF)] } {
          eval $dispatch(EOF)
        }
        return
      }
      cmd-log debug "Recieved: $line"
      if { [set pos      [string first " :" $line]] > -1 } {
        set header      [string range $line 0 [expr {$pos - 1}]]
        set linedata(msg)  [string range $line [expr {$pos + 2}] end]
      } else {
        set header      [string trim $line]
        set linedata(msg)  {}
      }

      if { [string match :* $header] } {
        set header  [split [string trimleft $header :]]
      } else {
        set header  [linsert [split $header] 0 {}]
      }
      set linedata(rawline)      [string trim $line];
      set linedata(who)          [string trim [lindex $header 0]];
      set linedata(action)      [string trim [lindex $header 1]];
      set linedata(target)      [string trim [lindex $header 2]];
      set linedata(additional)  [string trim [lrange $header 3 end]];
      set linedata(numname)      [::IRCC::num2name [lindex $header 1]];
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
      set dispatch($evnt)  $cmd
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
      if { [info proc [namespace current]::cmd-$cmd] == "" } {
        return "sub-cmd inconnu. List: [join [string map [list "[namespace current]::cmd-" ""] [info proc [namespace current]::cmd-*]] ", "]"
      } else {
        eval [linsert $args 0 [namespace current]::cmd-$cmd]
      }
    }

    # Create default handlers.

    set dispatch(PING)        {network send "PONG :[msg]"}
    set dispatch(defaultevent)    #
    set dispatch(defaultcmd)    #
    set dispatch(defaultnumeric)  #
  }

  set returncommand  [format "%s::IRCC%s::network" [namespace current] $conn]
  incr conn
  return $returncommand
}

# -------------------------------------------------------------------------

package provide IRCC $::IRCC::pkg_vers
package require Tcl $::IRCC::pkg_vers_min_need_tcl
package require tls $::IRCC::pkg_vers_min_need_tls

# -------------------------------------------------------------------------
return
