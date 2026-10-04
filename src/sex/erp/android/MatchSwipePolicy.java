package sex.erp.android;

final class MatchSwipePolicy {
    static boolean horizontal(float x,float y,int slop){return Math.abs(x)>slop&&Math.abs(x)>Math.abs(y)*1.3f;}
    static boolean reveal(float offset,int width,float velocity){
        if(velocity<-700)return true;if(velocity>700)return false;
        return offset<-width*.4f;
    }
}
