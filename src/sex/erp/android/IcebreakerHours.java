package sex.erp.android;

import java.util.ArrayList;
import java.util.TreeSet;

final class IcebreakerHours {
    static String format(int[] hours){
        TreeSet<Integer> unique=new TreeSet<>();for(int hour:hours)if(hour>=0&&hour<24)unique.add(hour);
        ArrayList<int[]> ranges=new ArrayList<>();for(int hour:unique){int[] last=ranges.isEmpty()?null:ranges.get(ranges.size()-1);if(last!=null&&last[1]==hour)last[1]=hour+1;else ranges.add(new int[]{hour,hour+1});}
        if(ranges.size()>1&&ranges.get(0)[0]==0&&ranges.get(ranges.size()-1)[1]==24){int[] first=ranges.remove(0);ranges.get(ranges.size()-1)[1]=first[1];}
        ArrayList<String> result=new ArrayList<>();for(int[] range:ranges)result.add(range[0]+"–"+range[1]);return String.join(", ",result);
    }
}
