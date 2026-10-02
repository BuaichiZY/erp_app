package sex.erp.android;

import java.util.*;

final class LikesRules {
    static String endpoint(String kind){return "visitors".equals(kind)?"/visitors":"sent".equals(kind)?"/likes/sent":"/likes/received";}
    static String actionState(boolean blocked,String matchState,String matchId,String swiped,boolean paused){
        if(blocked)return "blocked";
        if("active".equals(matchState)&&matchId!=null&&!matchId.isEmpty())return "matched";
        if(swiped!=null&&!swiped.isEmpty()&&!"none".equals(swiped))return swiped;
        return paused?"paused":"available";
    }
    static boolean canCancel(String kind,boolean cancelable,boolean feature){return "sent".equals(kind)&&cancelable&&feature;}
    static String hours(Collection<Integer> values){
        TreeSet<Integer> sorted=new TreeSet<>();for(Integer hour:values)if(hour!=null&&hour>=0&&hour<24)sorted.add(hour);
        ArrayList<int[]> ranges=new ArrayList<>();for(int hour:sorted){if(!ranges.isEmpty()&&ranges.get(ranges.size()-1)[1]==hour)ranges.get(ranges.size()-1)[1]=hour+1;else ranges.add(new int[]{hour,hour+1});}
        if(ranges.size()>1&&ranges.get(0)[0]==0&&ranges.get(ranges.size()-1)[1]==24){int[] first=ranges.remove(0);ranges.get(ranges.size()-1)[1]=first[1];}
        ArrayList<String> output=new ArrayList<>();for(int[] range:ranges)output.add(range[0]+"–"+range[1]);return String.join("、",output);
    }
}
