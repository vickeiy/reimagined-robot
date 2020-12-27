import sys
import time
import struct

#+
# Useful stuff
#-            

def structread(fromfile, decode_struct) :
    """reads sufficient bytes from fromfile to be unpacked according to
    decode_struct, and returns the unpacked results."""                
    return struct.unpack(decode_struct, fromfile.read(struct.calcsize(decode_struct)))
#end structread                                                                       

def format_time(the_time) :
    """formats a UTC time in printable form."""
    return "%4u-%02u-%02u %02u:%02u:%02uZ" % time.gmtime(the_time)[0:6]
#end format_time                                                       

#+
# Mainline
#-        

if len(sys.argv) != 2 :
    raise RuntimeError("need exactly one arg, the name of the zone file to dump")
#end if                                                                          

zonefile = open(sys.argv[1], "rb")
try_long = False
while True :
    (sig, ver, tzh_ttisgmtcnt, tzh_ttisstdcnt, tzh_leapcnt, tzh_timecnt, tzh_typecnt, tzh_charcnt) = \
        structread(zonefile, ">4s1B15x6I")
    if sig != "TZif" :
        raise RuntimeError("invalid zonefile signature %r" % sig)
    #end if
    print \
      (
            "ver = %u, tzh_ttisgmtcnt = %u, tzh_ttisstdcnt = %u, tzh_leapcnt = %u,"
            " tzh_timecnt = %u, tzh_typecnt = %u, tzh_charcnt = %u"
        %
            (ver, tzh_ttisgmtcnt, tzh_ttisstdcnt, tzh_leapcnt, tzh_timecnt, tzh_typecnt, tzh_charcnt)        
      )

    # initial content decode
    transition = structread(zonefile, ">" + ("q" if try_long else "i") * tzh_timecnt)
    transition_type = structread(zonefile, ">" + "B" * tzh_timecnt)
    ttinfo = structread(zonefile, ">" + "iBB" * tzh_typecnt)
    ttinfo = tuple(ttinfo[i * 3 : i * 3 + 3] for i in range(0, len(ttinfo) // 3))
    zone_abbrevs = structread(zonefile, ">%us" % tzh_charcnt)[0]
    leap_transition = structread(zonefile, ">" + "II" * tzh_leapcnt)
    isstd = structread(zonefile, ">" + "B" * tzh_ttisstdcnt)
    isgmt = structread(zonefile, ">" + "B" * tzh_ttisgmtcnt)
    if False :
        print("transition:")
        for t in transition :
            print(" %u => %s" % (t, format_time(t)))
        #end for
    else :
        print("transition = %r" % transition)
    #end if
    print("transition_type = %r" % transition_type)
    print("ttinfo = %r" % ttinfo)
    print("zone_abbrevs = %r" % zone_abbrevs)
    print("leap_transition = %r" % leap_transition)
    print("isstd = %r" % isstd)
    print("isgmt = %r" % isgmt)
    if try_long or ver < ord("2") :
        break
    try_long = True
#end while
zonefile.close()

# build combined ttinfo structs
ttinfo = tuple \
  (
        {
          "tt_gmtoff" : t[0],
          "tt_isdst"  : t[1] != 0,
          "tt_abbrev" : zone_abbrevs[t[2] : t[2] + zone_abbrevs[t[2]:].find("\0")],
          "tt_ttisstd": s != 0,
          "tt_ttisgmt": g != 0,
        }
    for
        t, s, g in zip(ttinfo, isstd, isgmt)
  )
print("decoded ttinfo = %r" % ttinfo)

# display all the transitions
print("transition:")
for x,y in zip(transition, transition_type) :
    print \
      (
            " %u => %s %+d"
        %
            (x, format_time(x), ttinfo[y]["tt_gmtoff"])
      )
#end for
