package sex.erp.android;

public final class MatchSwipePolicyTest {
    private static void check(boolean value){if(!value)throw new AssertionError();}
    public static void main(String[] args){
        check(!MatchSwipePolicy.horizontal(4,2,8));check(!MatchSwipePolicy.horizontal(20,60,8));
        check(!MatchSwipePolicy.horizontal(50,45,8));check(MatchSwipePolicy.horizontal(-80,10,8));
        check(MatchSwipePolicy.horizontal(80,10,8));check(!MatchSwipePolicy.reveal(0,208,0));
        check(!MatchSwipePolicy.reveal(-60,208,0));check(MatchSwipePolicy.reveal(-100,208,0));
        check(MatchSwipePolicy.reveal(-25,208,-900));check(!MatchSwipePolicy.reveal(-190,208,900));
        System.out.println("Match swipe menu: taps, vertical scrolling, reveal and close passed");
    }
}
