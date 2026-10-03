package io.flutter.plugin.editing;

import static org.junit.Assert.*;
import android.app.Activity;
import android.graphics.Insets;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsAnimation;
import java.util.Collections;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.android.controller.ActivityController;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 30, manifest = Config.NONE)
public class ImeSyncDeferringInsetsCallbackTest {
  private ActivityController<Activity> host;
  private RecordingView view;
  private ImeSyncDeferringInsetsCallback callback;
  private static WindowInsets inset(int bottom) {
    return new WindowInsets.Builder().setInsets(WindowInsets.Type.ime(), Insets.of(0,0,0,bottom))
        .setVisible(WindowInsets.Type.ime(), bottom > 0).build();
  }
  private static WindowInsetsAnimation animation() {
    return new WindowInsetsAnimation(WindowInsets.Type.ime(), null, 200);
  }
  @Before public void setUp() {
    host = Robolectric.buildActivity(Activity.class).setup().visible();
    view = new RecordingView(host.get());
    host.get().setContentView(view);
    callback = new ImeSyncDeferringInsetsCallback(view);
    callback.install();
    view.dispatchApplyWindowInsets(inset(600));
    assertEquals(600, view.bottom);
  }
  @After public void tearDown() { callback.remove(); host.pause().stop().destroy(); }
  @Test public void hideInterruptedByGoneAppliesFinalInsetWithoutEnd() {
    callback.getAnimationCallback().onPrepare(animation());
    view.setVisibility(View.GONE);
    view.dispatchApplyWindowInsets(inset(0));
    assertEquals(0, view.bottom);
    view.setVisibility(View.VISIBLE);
    view.dispatchApplyWindowInsets(inset(0));
    assertEquals(0, view.bottom);
  }
  @Test public void stoppedHostCancelsDeferralEvenBeforeVisibilityChanges() {
    callback.getAnimationCallback().onPrepare(animation());
    host.pause().stop();
    view.dispatchApplyWindowInsets(inset(0));
    assertEquals(0, view.bottom);
    host.start().resume().visible();
    view.dispatchApplyWindowInsets(inset(0));
    assertEquals(0, view.bottom);
  }
  @Test public void lateOldEndAndProgressCannotFinishNewAnimation() {
    WindowInsetsAnimation old = animation();
    callback.getAnimationCallback().onPrepare(old);
    view.setVisibility(View.GONE);
    view.dispatchApplyWindowInsets(inset(0));
    view.setVisibility(View.VISIBLE);
    WindowInsetsAnimation current = animation();
    callback.getAnimationCallback().onPrepare(current);
    view.dispatchApplyWindowInsets(inset(600));
    callback.getAnimationCallback().onEnd(old);
    callback.getAnimationCallback().onProgress(inset(450), Collections.singletonList(old));
    assertEquals(0, view.bottom);
    callback.getAnimationCallback().onProgress(inset(300), Collections.singletonList(current));
    assertEquals(300, view.bottom);
    callback.getAnimationCallback().onEnd(current);
    assertEquals(600, view.bottom);
  }
  @Test public void normalShowAndHideStillAnimateAndApplyFinalInsets() {
    for (int bottom : new int[] {0, 600, 0}) {
      WindowInsetsAnimation current = animation();
      callback.getAnimationCallback().onPrepare(current);
      view.dispatchApplyWindowInsets(inset(bottom));
      callback.getAnimationCallback().onProgress(inset(200), Collections.singletonList(current));
      assertEquals(200, view.bottom);
      callback.getAnimationCallback().onEnd(current);
      assertEquals(bottom, view.bottom);
    }
  }
  @Test public void detachedHostIgnoresLateAnimationEnd() {
    WindowInsetsAnimation old = animation();
    callback.getAnimationCallback().onPrepare(old);
    view.dispatchApplyWindowInsets(inset(0));
    host.get().setContentView(new View(host.get()));
    callback.getAnimationCallback().onEnd(old);
    host.get().setContentView(view);
    view.dispatchApplyWindowInsets(inset(0));
    assertEquals(0, view.bottom);
  }
  static class RecordingView extends View {
    int bottom;
    RecordingView(Activity activity) { super(activity); }
    @Override public WindowInsets onApplyWindowInsets(WindowInsets insets) {
      bottom = insets.getInsets(WindowInsets.Type.ime()).bottom;
      return insets;
    }
  }
}
