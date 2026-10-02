package sex.erp.android;

public final class DiscoverFiltersTest {
    private static int checks;
    private static void check(boolean condition){if(!condition)throw new AssertionError("Check "+(checks+1));checks++;}
    public static void main(String[] args){
        DiscoverFilters applied=new DiscoverFilters();check(applied.count(true)==0);check(applied.query(true).isEmpty());
        applied.select("languages","zh",true);applied.select("languages","en",true);applied.select("languages","zh",true);
        check(applied.count(true)==1);check(applied.query(true).equals("&languages=en%2Czh"));
        applied.select("platforms","pcvr",true);applied.flag("fullBody",true);applied.flag("onlineNow",true);
        check(applied.count(true)==4);check(applied.count(false)==3);check(!applied.query(false).contains("onlineNow"));check(applied.query(true).contains("&fullBody=true"));
        DiscoverFilters draft=applied.copy();draft.select("languages","zh",false);draft.flag("nearTimezone",true);
        check(applied.selected("languages","zh"));check(!applied.flag("nearTimezone"));check(!draft.selected("languages","zh"));check(draft.flag("nearTimezone"));
        String saved=applied.query(true);check(DiscoverFilters.parse(saved).query(true).equals(saved));draft.clear();check(draft.query(true).isEmpty());check(applied.query(true).equals(saved));
        DiscoverFilters unknown=DiscoverFilters.parse("&admin=true&languages=zh%2CINVALID&platforms=android&fullBody=1&onlineNow=false&voice=male&nearTimezone=true");
        check(unknown.query(true).equals("&languages=zh&voice=male&nearTimezone=true"));check(unknown.count(true)==3);
        DiscoverFilters malformed=DiscoverFilters.parse("&languages=%XY&voice=male&empty=&onlineNow=true");check(malformed.query(false).equals("&voice=male"));check(malformed.count(false)==1);
        for(int group=0;group<DiscoverFilters.KEYS.length;group++){
            DiscoverFilters all=new DiscoverFilters();for(String value:DiscoverFilters.VALUES[group])all.select(DiscoverFilters.KEYS[group],value,true);
            check(all.count(true)==1);check(DiscoverFilters.parse(all.query(true)).query(true).equals(all.query(true)));
            for(String value:DiscoverFilters.VALUES[group])check(all.selected(DiscoverFilters.KEYS[group],value));
        }
        applied.flag("fullBody",false);check(!applied.query(true).contains("fullBody"));applied.select("languages","en",false);check(applied.query(true).contains("languages=zh"));
        System.out.println("Discover filter checks passed: "+checks);
    }
}
