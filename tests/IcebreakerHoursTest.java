package sex.erp.android;

public final class IcebreakerHoursTest {
    public static void main(String[] args){
        if(!"22–3".equals(IcebreakerHours.format(new int[]{0,1,2,22,23,22})))throw new AssertionError("Midnight-spanning hours");
        if(!"9–11, 20–22".equals(IcebreakerHours.format(new int[]{9,10,20,21})))throw new AssertionError("Separate ranges");
        if(!"".equals(IcebreakerHours.format(new int[]{})))throw new AssertionError("Empty hours");
        System.out.println("Icebreaker shared hours checks passed");
    }
}
