package sex.erp.android;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Compares the project's release tags with the installed Android version name. */
final class ReleaseVersion {
    private static final Pattern VERSION=Pattern.compile("(?:^|[^0-9])(\\d+)\\.(\\d+)\\.(\\d+)(?:[-_]([A-Za-z0-9.-]+))?");
    static int compare(String release,String installed){
        Matcher latest=VERSION.matcher(release),current=VERSION.matcher(installed);
        if(!latest.find()||!current.find())return Integer.MIN_VALUE;
        for(int part=1;part<=3;part++){int a=Integer.parseInt(latest.group(part)),b=Integer.parseInt(current.group(part));if(a!=b)return Integer.compare(a,b);}
        String a=latest.group(4),b=current.group(4);
        if(a==null)return b==null?0:1;if(b==null)return -1;
        return a.toLowerCase(Locale.ROOT).compareTo(b.toLowerCase(Locale.ROOT));
    }
    static boolean newer(String release,String installed){return compare(release,installed)>0;}
}
