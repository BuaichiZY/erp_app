package sex.erp.android;

import java.util.*;

public final class LikesRulesTest {
    private static int checks;
    private static void eq(Object a,Object b){checks++;if(!a.equals(b))throw new AssertionError(a+" != "+b);}
    public static void main(String[] args){
        eq(LikesRules.endpoint("received"),"/likes/received");eq(LikesRules.endpoint("sent"),"/likes/sent");eq(LikesRules.endpoint("secret"),"/likes/secret");eq(LikesRules.endpoint("visitors"),"/visitors");
        eq(LikesRules.actionState(true,"active","match","like",false),"blocked");
        eq(LikesRules.actionState(false,"active","match","superlike",true),"matched");
        eq(LikesRules.actionState(false,"unmatched","match","like",false),"like");
        eq(LikesRules.actionState(false,"active","","none",false),"available");
        eq(LikesRules.actionState(false,"","","none",true),"paused");
        eq(LikesRules.actionState(false,"","","pass",true),"pass");
        eq(LikesRules.actionState(false,null,null,null,false),"available");
        eq(LikesRules.canCancel("sent",true,true),true);
        eq(LikesRules.canCancel("secret",true,true),true);
        eq(LikesRules.canCancel("received",true,true),false);
        eq(LikesRules.canCancel("visitors",true,true),false);
        eq(LikesRules.canCancel("sent",false,true),false);
        eq(LikesRules.canCancel("sent",true,false),false);
        eq(LikesRules.hours(Arrays.asList(23,0,22)),"22–1");
        eq(LikesRules.hours(Arrays.asList(3,2,3,8,9)),"2–4、8–10");
        eq(LikesRules.hours(Arrays.asList(-1,24,null)),"");
        eq(LikesRules.hours(Arrays.asList(0,1,22,23,6)),"6–7、22–2");
        List<Integer> day=new ArrayList<>();for(int i=0;i<24;i++)day.add(i);eq(LikesRules.hours(day),"0–24");
        System.out.println("Likes rules: "+checks+" checks passed");
    }
}
