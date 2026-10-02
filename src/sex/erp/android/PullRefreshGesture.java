package sex.erp.android;

/** A page gesture must start at the top, be vertical, and reach 96 dp. */
final class PullRefreshGesture {
    static final float DISTANCE = 96f;
    private final float slop;
    private boolean eligible, dragging;
    private float distance;

    PullRefreshGesture(float slop) { this.slop = slop; }
    static boolean allowsStart(boolean blankOnly,boolean interactive){return !blankOnly||!interactive;}
    void start(boolean blank, boolean atTop, boolean busy) {
        eligible = blank && atTop && !busy;
        dragging = false;
        distance = 0;
    }
    boolean move(float dx, float dy, int pointers) {
        if (pointers != 1) { cancel(); return false; }
        if (!eligible) return false;
        if (!dragging) {
            if (Math.max(Math.abs(dx), Math.abs(dy)) <= slop) return false;
            if (dy <= slop || dy <= Math.abs(dx) * 1.5f) { cancel(); return false; }
            dragging = true;
        }
        distance = Math.max(0, dy);
        return true;
    }
    boolean eligible() { return eligible; }
    boolean ready() { return dragging && distance >= DISTANCE; }
    float progress() { return Math.min(1, distance / DISTANCE); }
    boolean release() { boolean refresh = ready(); cancel(); return refresh; }
    void cancel() { eligible = dragging = false; distance = 0; }
}
