package sex.erp.android;

public final class PullRefreshGestureTest {
    private static int checks;
    private static void check(boolean condition) { if(!condition)throw new AssertionError("Check "+(checks+1));checks++; }
    public static void main(String[] args) {
        PullRefreshGesture g=new PullRefreshGesture(8);
        check(PullRefreshGesture.allowsStart(false,true));check(PullRefreshGesture.allowsStart(false,false));
        check(!PullRefreshGesture.allowsStart(true,true));check(PullRefreshGesture.allowsStart(true,false));
        g.start(PullRefreshGesture.allowsStart(false,true),true,false);check(g.move(0,120,1));check(g.release());
        g.start(PullRefreshGesture.allowsStart(true,true),true,false);check(!g.move(0,120,1));check(!g.release());
        g.start(true,true,false);check(!g.move(0,8,1));check(!g.ready());check(!g.release());
        g.start(true,true,false);check(g.move(2,40,1));check(!g.ready());check(!g.release());
        g.start(true,true,false);check(g.move(0,95,1));check(!g.release());
        g.start(true,true,false);check(g.move(0,96,1));check(g.ready());check(g.progress()==1);check(g.release());check(!g.release());
        g.start(true,true,false);check(g.move(2,300,1));check(g.progress()==1);check(g.release());
        g.start(false,true,false);check(!g.move(0,200,1));check(!g.release());
        g.start(true,false,false);check(!g.move(0,200,1));check(!g.release());
        g.start(true,true,true);check(!g.move(0,200,1));check(!g.release());
        g.start(true,true,false);check(!g.move(110,60,1));check(!g.move(0,200,1));check(!g.release());
        g.start(true,true,false);check(!g.move(0,-40,1));check(!g.move(0,200,1));check(!g.release());
        g.start(true,true,false);check(g.move(10,120,1));check(g.move(2,20,1));check(!g.ready());check(!g.release());
        g.start(true,true,false);check(g.move(0,120,1));g.cancel();check(!g.release());
        g.start(true,true,false);check(g.move(0,120,1));check(!g.move(0,150,2));check(!g.move(0,180,1));check(!g.release());
        g.start(true,true,false);check(g.move(0,120,1));g.start(false,true,false);check(!g.release());
        g.start(true,true,false);check(g.move(0,100,1));check(g.move(0,-10,1));check(g.progress()==0);check(!g.release());
        System.out.println("Pull refresh gesture checks passed: "+checks);
    }
}
