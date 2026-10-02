package sex.erp.android;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Presentation rules shared by the conversation list and message timeline. */
final class ChatPresentation {
    static String vrcLabel(){return "我的 VRChat 主页";}
    static boolean vrcProfileUrl(String raw){try{java.net.URI uri=new java.net.URI(raw);return "https".equalsIgnoreCase(uri.getScheme())&&"vrchat.com".equalsIgnoreCase(uri.getHost())&&uri.getUserInfo()==null&&(uri.getPort()==-1||uri.getPort()==443)&&uri.getPath()!=null&&uri.getPath().matches("/home/user/usr_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/?");}catch(Exception ignored){return false;}}
    static String system(String key) {
        if(key==null||key.isEmpty()||"matched".equals(key))return "你们已成功配对";
        if("unmatched".equals(key))return "配对已解除";
        if("blocked".equals(key))return "此配对已结束";
        if("boundary_ack".equals(key)||"boundary_acked".equals(key))return "已确认交流边界";
        if("vrc_shared".equals(key))return "已共享 VRChat 信息";
        return key.matches("[a-z_]+")?"配对状态已更新":key;
    }
    static String preview(String type,String text,boolean recalled,boolean mine) {
        if(recalled)return "消息已撤回";
        if("system".equals(type))return system(text);
        if("notice".equals(type))return "公告"+(text==null||text.isEmpty()?"":"："+text);
        String prefix=mine?"你：":"";
        if("image".equals(type))return prefix+"[图片]";
        if("voice".equals(type))return prefix+"[语音]";
        if("vrc_link".equals(type))return prefix+"[VRChat 信息]";
        return prefix+(text==null?"":text);
    }
    static String time(String iso,String pattern) {
        long stamp=EnergyTime.timestamp(iso);
        return stamp<0?"":new SimpleDateFormat(pattern,Locale.CHINA).format(new Date(stamp));
    }
    static boolean canSend(String state,boolean closedReason,boolean boundaryRequired,boolean myAck,boolean restricted) {
        return "active".equals(state)&&!closedReason&&(!boundaryRequired||myAck)&&!restricted;
    }
    static boolean canRecall(String iso,long now,int seconds) {
        long stamp=EnergyTime.timestamp(iso);
        return stamp>=0&&now>=stamp&&now-stamp<Math.max(0,seconds)*1000L;
    }
}
