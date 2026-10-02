package sex.erp.android;

import java.text.SimpleDateFormat;
import java.util.Locale;
import java.util.TimeZone;

final class EnergyTime {
    static long timestamp(String iso){if(iso==null||iso.isEmpty())return -1;for(String pattern:new String[]{"yyyy-MM-dd'T'HH:mm:ss.SSSXXX","yyyy-MM-dd'T'HH:mm:ssXXX"})try{SimpleDateFormat formatter=new SimpleDateFormat(pattern,Locale.ROOT);formatter.setTimeZone(TimeZone.getTimeZone("UTC"));formatter.setLenient(false);java.text.ParsePosition position=new java.text.ParsePosition(0);java.util.Date date=formatter.parse(iso,position);if(date!=null&&position.getIndex()==iso.length())return date.getTime();}catch(Exception ignored){}return -1;}
    static String countdown(long seconds){seconds=Math.max(0,seconds);return seconds>=3600?String.format(Locale.ROOT,"%d:%02d:%02d",seconds/3600,(seconds/60)%60,seconds%60):String.format(Locale.ROOT,"%d:%02d",seconds/60,seconds%60);}
}
