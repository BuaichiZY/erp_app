package sex.erp.android;

import java.util.*;

public final class ProfileTextTest {
    private static int checks;
    private static void eq(String expected,Object record){checks++;String actual=ProfileText.read(record);if(!expected.equals(actual))throw new AssertionError(expected+" != "+actual);}
    public static void main(String[] args){
        eq("旧版简介\n第二行","旧版简介\n第二行");eq("",null);eq("",42);
        Map<String,Object> bio=new HashMap<>();bio.put("text","还是睡不醒嘛。\n没有音乐会消失");bio.put("lang","zh");bio.put("source","original");bio.put("translating",false);
        eq("还是睡不醒嘛。\n没有音乐会消失",bio);
        bio.put("originalText","Original bio");eq("还是睡不醒嘛。\n没有音乐会消失",bio);
        bio.put("text","");eq("Original bio",bio);bio.put("text","   ");eq("Original bio",bio);
        bio.remove("text");eq("Original bio",bio);bio.remove("originalText");eq("",bio);
        eq("",Collections.singletonMap("source","ai"));
        System.out.println("ProfileTextTest: "+checks+" checks passed");
    }
}
