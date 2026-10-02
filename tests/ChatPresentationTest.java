package sex.erp.android;

import java.util.TimeZone;

public final class ChatPresentationTest {
    private static int checks;
    private static void eq(Object actual,Object expected){checks++;if(!actual.equals(expected))throw new AssertionError(actual+" != "+expected);}
    public static void main(String[] args){
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"));
        String profile="https://vrchat.com/home/user/usr_fb2d7e51-7df9-4de2-9e05-9f36dda59c36";
        eq(ChatPresentation.vrcLabel(),"我的 VRChat 主页");
        eq(ChatPresentation.vrcProfileUrl(profile),true);
        eq(ChatPresentation.vrcProfileUrl(profile+"?ref=share"),true);
        eq(ChatPresentation.vrcProfileUrl(profile.replace("https:","http:")),false);
        eq(ChatPresentation.vrcProfileUrl(profile.replace("vrchat.com","vrchat.com.example.org")),false);
        eq(ChatPresentation.vrcProfileUrl(profile.replace("vrchat.com","attacker@vrchat.com")),false);
        eq(ChatPresentation.vrcProfileUrl(profile.replace("vrchat.com","vrchat.com:8443")),false);
        eq(ChatPresentation.vrcProfileUrl(profile.replace("/user/","/world/")),false);
        eq(ChatPresentation.vrcProfileUrl(profile+"/../settings"),false);
        eq(ChatPresentation.vrcProfileUrl("javascript:alert(1)"),false);
        eq(ChatPresentation.vrcProfileUrl(null),false);
        eq(ChatPresentation.vrcProfileUrl("https://vrchat.com/home/user/usr_"),false);
        eq(ChatPresentation.preview("system","matched",false,false),"你们已成功配对");
        eq(ChatPresentation.preview("image","",false,true),"你：[图片]");
        eq(ChatPresentation.preview("voice","",false,false),"[语音]");
        eq(ChatPresentation.preview("vrc_link","https://vrchat.com",false,false),"[VRChat 信息]");
        eq(ChatPresentation.preview("text","你好",false,true),"你：你好");
        eq(ChatPresentation.preview("image","",true,true),"消息已撤回");
        eq(ChatPresentation.preview("notice","系统公告",false,false),"公告：系统公告");
        eq(ChatPresentation.preview("text",null,false,false),"");
        eq(ChatPresentation.time("2026-10-01T16:14:00Z","HH:mm"),"00:14");
        eq(ChatPresentation.time("2026-10-01T16:14:00Z","yyyy年MM月dd日"),"2026年10月02日");
        eq(ChatPresentation.time("invalid","HH:mm"),"");
        eq(ChatPresentation.time("2026-10-02T00:14:00+08:00","HH:mm"),"00:14");
        for(String state:new String[]{"active","unmatched","blocked"})for(boolean reason:new boolean[]{true,false})for(boolean required:new boolean[]{true,false})for(boolean ack:new boolean[]{true,false})for(boolean restricted:new boolean[]{true,false}){
            boolean expected="active".equals(state)&&!reason&&(!required||ack)&&!restricted;
            eq(ChatPresentation.canSend(state,reason,required,ack,restricted),expected);
        }
        long stamp=EnergyTime.timestamp("2026-10-01T16:14:00Z");
        eq(ChatPresentation.canRecall("2026-10-01T16:14:00Z",stamp+119999,120),true);
        eq(ChatPresentation.canRecall("2026-10-01T16:14:00Z",stamp+120000,120),false);
        eq(ChatPresentation.canRecall("2026-10-01T16:14:00Z",stamp-1,120),false);
        eq(ChatPresentation.canRecall("invalid",stamp,120),false);
        System.out.println("Chat presentation: "+checks+" checks passed");
    }
}
