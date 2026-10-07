package sex.erp.android;

import java.text.Normalizer;
import java.util.Locale;

/** Case-insensitive substring matching for match names, including single CJK characters. */
final class MatchSearch {
    private MatchSearch() {}

    static boolean matches(String displayName, String username, String query) {
        String needle = normalize(query).trim();
        return needle.isEmpty() || normalize(displayName).contains(needle) || normalize(username).contains(needle);
    }

    private static String normalize(String value) {
        return Normalizer.normalize(value == null ? "" : value, Normalizer.Form.NFKC).toLowerCase(Locale.ROOT);
    }
}
