package sex.erp.android;

import java.util.*;

/** Small session-only snapshots. Never persists account data or chat messages. */
final class ReadResponseCache {
    private static final class Entry {
        final String path, value; final long expires;
        Entry(String path,String value,long expires){this.path=path;this.value=value;this.expires=expires;}
    }
    private final LinkedHashMap<String,Entry> entries=new LinkedHashMap<>(16,.75f,true);
    private int bytes;
    static long lifetime(String path){
        String route=path.split("\\?",2)[0];
        if(route.equals("/config"))return 300000;
        if(route.equals("/me"))return 30000;
        if(route.equals("/me/energy"))return 10000;
        if(route.equals("/me/passes"))return 30000;
        if(route.equals("/matches"))return 10000;
        if(route.equals("/feed")||route.equals("/public/feed")||route.equals("/likes/received")||route.equals("/likes/sent")||route.equals("/visitors"))return 15000;
        if(route.equals("/posts"))return 20000;
        return 0; // Security, notifications, profiles and chat always use the server.
    }
    synchronized String get(String context,String path,long now){
        String key=context+"\n"+path;Entry entry=entries.get(key);
        if(entry==null)return null;
        if(now>=entry.expires){entries.remove(key);bytes-=entry.value.length()*2;return null;}
        return entry.value;
    }
    synchronized void put(String context,String path,String value,long now){
        long ttl=lifetime(path);if(ttl==0||value.length()>512*1024)return;
        String key=context+"\n"+path;Entry old=entries.remove(key);if(old!=null)bytes-=old.value.length()*2;
        entries.put(key,new Entry(path,value,now+ttl));bytes+=value.length()*2;
        Iterator<Entry> iterator=entries.values().iterator();
        while((bytes>4*1024*1024||entries.size()>64)&&iterator.hasNext()){Entry removed=iterator.next();bytes-=removed.value.length()*2;iterator.remove();}
    }
    synchronized void invalidate(String path){
        Iterator<Entry> iterator=entries.values().iterator();
        while(iterator.hasNext()){Entry entry=iterator.next();boolean remove;
            if(path.endsWith("/read"))remove=entry.path.startsWith("/matches");
            else if(path.equals("message"))remove=entry.path.startsWith("/matches");
            else if(path.equals("energy"))remove=entry.path.equals("/me")||entry.path.startsWith("/me/energy");
            else remove=!entry.path.equals("/config")||path.startsWith("/auth/");
            if(remove){bytes-=entry.value.length()*2;iterator.remove();}
        }
    }
    synchronized void clear(){entries.clear();bytes=0;}
}
