package sex.erp.android;

public final class SwipeGesturePolicyTest {
    private static int checks;
    private static void action(float x,float y,float vx,String expected){String actual=SwipeGesturePolicy.action(x,y,vx);if(expected==null?actual!=null:!expected.equals(actual))throw new AssertionError("Unexpected direction at "+x+","+y+","+vx+": "+actual);checks++;}
    private static void near(float actual,float expected){if(Math.abs(actual-expected)>.001f)throw new AssertionError(actual+" != "+expected);checks++;}
    public static void main(String[] args){
        action(0,220,0,null);action(80,180,1200,null);action(-80,180,-1200,null);
        action(0,-121,0,"superlike");action(110,-180,800,"superlike");
        action(-121,0,0,"pass");action(121,0,0,"like");
        action(20,0,701,"like");action(-20,0,-701,"pass");
        action(-180,10,1200,"pass");action(180,10,-1200,"like");
        action(-20,0,1200,null);action(20,0,-1200,null);
        action(120,0,0,null);action(-120,0,0,null);action(0,-120,0,null);
        action(20,25,200,null);action(0,0,0,null);action(150,-200,0,"like");
        near(SwipeGesturePolicy.rotation(300),14);near(SwipeGesturePolicy.rotation(-300),-14);
        near(SwipeGesturePolicy.rotation(600),14);near(SwipeGesturePolicy.rotation(150),7);
        near(SwipeGesturePolicy.likeOpacity(30),0);near(SwipeGesturePolicy.likeOpacity(140),1);
        near(SwipeGesturePolicy.passOpacity(-30),0);near(SwipeGesturePolicy.passOpacity(-140),1);
        near(SwipeGesturePolicy.superOpacity(-40),0);near(SwipeGesturePolicy.superOpacity(-140),1);
        near(SwipeGesturePolicy.superOpacity(180),0);
        System.out.println("Swipe gesture checks passed: "+checks);
    }
}
