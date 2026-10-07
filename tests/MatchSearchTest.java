package sex.erp.android;

public final class MatchSearchTest {
    public static void main(String[] args) {
        check(MatchSearch.matches("沙华Candy", "", "华"), "single Chinese character");
        check(MatchSearch.matches("沙华Candy", "", "CAN"), "case-insensitive Latin substring");
        check(MatchSearch.matches("月代·音梦", "user_fox", "FOX"), "username substring");
        check(MatchSearch.matches("ＡＢＣ", "", "bc"), "full-width Latin normalization");
        check(MatchSearch.matches("任何名字", "", "  "), "empty query");
        check(!MatchSearch.matches("沙华Candy", "", "兔"), "unmatched character");
    }

    private static void check(boolean passed, String description) {
        if (!passed) throw new AssertionError(description);
    }
}
