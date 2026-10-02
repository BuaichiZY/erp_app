package sex.erp.android;

/** Distances and velocities are in density independent pixels, matching the web card. */
final class SwipeGesturePolicy {
    static String action(float x,float y,float velocityX){
        // A downward gesture always rebounds, including a fast diagonal release.
        if(y>0&&Math.abs(y)>=Math.abs(x))return null;
        if(y<-120&&Math.abs(x)<120)return "superlike";
        if(x>120||velocityX>700)return "like";
        if(x<-120||velocityX<-700)return "pass";
        return null;
    }
    static float rotation(float x){return Math.max(-14,Math.min(14,x*14/300));}
    static float likeOpacity(float x){return clamp((x-30)/110);}
    static float passOpacity(float x){return clamp((-x-30)/110);}
    static float superOpacity(float y){return clamp((-y-40)/100);}
    private static float clamp(float n){return Math.max(0,Math.min(1,n));}
}
