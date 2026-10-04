package sex.erp.android;

public final class ReadResponseCacheTest {
    private static void check(boolean value){if(!value)throw new AssertionError();}
    public static void main(String[] args){
        ReadResponseCache cache=new ReadResponseCache();
        cache.put("sfw|en","/feed?limit=12","one",100);
        check("one".equals(cache.get("sfw|en","/feed?limit=12",101)));
        check(cache.get("nsfw|en","/feed?limit=12",101)==null);
        check(cache.get("sfw|ja","/feed?limit=12",101)==null);
        check(cache.get("sfw|en","/feed?limit=24",101)==null);
        check(cache.get("sfw|en","/feed?limit=12",15100)==null);
        for(String sensitive:new String[]{"/matches/abc/messages","/me/sessions","/notifications","/users/abc"}){
            cache.put("x",sensitive,"private",0);check(cache.get("x",sensitive,1)==null);
        }
        cache.put("x","/config","config",0);cache.put("x","/matches?state=active","matches",0);
        cache.put("x","/posts","posts",0);cache.put("x","/me","me",0);
        cache.invalidate("message");check(cache.get("x","/matches?state=active",1)==null);
        check("posts".equals(cache.get("x","/posts",1)));
        cache.invalidate("energy");check(cache.get("x","/me",1)==null);
        cache.invalidate("/swipes");check(cache.get("x","/posts",1)==null);
        check("config".equals(cache.get("x","/config",1)));
        cache.invalidate("/auth/logout");check(cache.get("x","/config",1)==null);
        check(ReadResponseCache.lifetime("/visitors")>0);
        for(int i=0;i<65;i++)cache.put("x","/feed?page="+i,"value",0);
        check(cache.get("x","/feed?page=0",1)==null);
        check("value".equals(cache.get("x","/feed?page=64",1)));
        cache.clear();check(cache.get("x","/feed?page=64",1)==null);
        System.out.println("Read snapshots: expiry, isolation, sensitive routes and invalidation passed");
    }
}
