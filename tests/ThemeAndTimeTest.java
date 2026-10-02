package sex.erp.android;

public final class ThemeAndTimeTest {
    private static int checks;
    private static void check(boolean value){if(!value)throw new AssertionError("Check "+(checks+1));checks++;}
    public static void main(String[] args){
        check(!ThemePalette.dark("light","nsfw",true,"dark"));check(ThemePalette.dark("dark","sfw",false,"light"));
        check(ThemePalette.dark("system","sfw",true,"light"));check(!ThemePalette.dark("system","nsfw",false,"dark"));
        check(!ThemePalette.dark("auto","sfw",true,"light"));check(ThemePalette.dark("auto","nsfw",false,"dark"));
        ThemePalette dark=new ThemePalette(true,false,0xffff5a4e),light=new ThemePalette(false,false,0xffff5a4e),adult=new ThemePalette(true,true,0xffff3e9a),adultLight=new ThemePalette(false,true,0xffff3e9a);
        check(adult.bg==0xff1b1233);check(adultLight.bg==0xffffeb7a);check(adultLight.pop);check(!light.pop);
        for(ThemePalette from:new ThemePalette[]{dark,light,adult,adultLight})for(ThemePalette to:new ThemePalette[]{dark,light,adult,adultLight}){
            check(from.recolor(from.bg,to)==to.bg);check(from.recolor(from.text,to)==to.text);check(from.recolor(from.surface,to)==to.surface);
            check(from.recolor(from.accent,to)==to.accent);check(from.recolor(0xffffffff,to)==0xffffffff);check(from.recolor(0,to)==0);
            check(from.recolor(from.border,to)==to.border);
        }
        check(EnergyTime.timestamp("2026-10-01T14:35:00.000Z")==EnergyTime.timestamp("2026-10-01T22:35:00+08:00"));
        check(EnergyTime.timestamp("2026-10-01T14:35:00Z")==1790865300000L);
        check(EnergyTime.timestamp("")==-1);check(EnergyTime.timestamp("invalid")==-1);check(EnergyTime.timestamp("2026-02-30T14:35:00Z")==-1);
        check(EnergyTime.timestamp("2026-10-01T14:35:00Zsuffix")==-1);
        check(EnergyTime.countdown(-1).equals("0:00"));check(EnergyTime.countdown(61).equals("1:01"));check(EnergyTime.countdown(3601).equals("1:00:01"));
        System.out.println("Theme and time checks passed: "+checks);
    }
}
