package sex.erp.android;

/** Reverses TextureView stretching, then rotates and uniformly fills the viewport. */
final class CameraPreviewGeometry {
    final float scaleX,scaleY,fillScale;
    final int rotation;

    private CameraPreviewGeometry(float scaleX,float scaleY,float fillScale,int rotation){
        this.scaleX=scaleX;this.scaleY=scaleY;this.fillScale=fillScale;this.rotation=rotation;
    }

    static CameraPreviewGeometry centerCrop(int viewWidth,int viewHeight,int bufferWidth,int bufferHeight,int sensorDegrees,int displayDegrees){
        if(viewWidth<=0||viewHeight<=0||bufferWidth<=0||bufferHeight<=0)throw new IllegalArgumentException("Empty preview");
        if(sensorDegrees%90!=0||displayDegrees%90!=0)throw new IllegalArgumentException("Invalid rotation");
        // TextureView already rotates the camera buffer into the sensor's natural orientation.
        boolean sensorSwapped=Math.floorMod(sensorDegrees,180)!=0;
        float naturalWidth=sensorSwapped?bufferHeight:bufferWidth;
        float naturalHeight=sensorSwapped?bufferWidth:bufferHeight;
        boolean displaySwapped=Math.floorMod(displayDegrees,180)!=0;
        float orientedWidth=displaySwapped?naturalHeight:naturalWidth;
        float orientedHeight=displaySwapped?naturalWidth:naturalHeight;
        float fill=Math.max(viewWidth/orientedWidth,viewHeight/orientedHeight);
        return new CameraPreviewGeometry(naturalWidth/viewWidth,naturalHeight/viewHeight,fill,-Math.floorMod(displayDegrees,360));
    }
}
