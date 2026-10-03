// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugin.editing;

import static io.flutter.Build.API_LEVELS;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.ContextWrapper;
import android.os.Bundle;
import android.view.ViewTreeObserver;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.Set;
import android.graphics.Insets;
import android.os.Build;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsAnimation;
import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.annotation.VisibleForTesting;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import java.util.List;

// Loosely based off of
// https://github.com/android/user-interface-samples/blob/main/WindowInsetsAnimation/app/src/main/java/com/google/android/samples/insetsanimation/RootViewDeferringInsetsCallback.kt
//
// When the IME is shown or hidden, it immediately sends an onApplyWindowInsets call
// with the final state of the IME. This initial call disrupts the animation, which
// causes a flicker in the beginning.
//
// To fix this, this class extends WindowInsetsAnimation.Callback and implements
// OnApplyWindowInsetsListener. We capture and defer the initial call to
// onApplyWindowInsets while the animation completes. When the animation
// finishes, we can then release the call by invoking it in the onEnd callback
//
// The WindowInsetsAnimation.Callback extension forwards the new state of the
// IME inset from onProgress() to the framework. We also make use of the
// onStart callback to detect which calls to onApplyWindowInsets would
// interrupt the animation and defer it.
//
// By implementing OnApplyWindowInsetsListener, we are able to capture Android's
// attempts to call the FlutterView's onApplyWindowInsets. When a call to onStart
// occurs, we can mark any non-animation calls to onApplyWindowInsets() that
// occurs between prepare and start as deferred by using this class' wrapper
// implementation to cache the WindowInsets passed in and turn the current call into
// a no-op. When onEnd indicates the end of the animation, the deferred call is
// dispatched again, this time avoiding any flicker since the animation is now
// complete.
@VisibleForTesting
@RequiresApi(API_LEVELS.API_30)
@SuppressLint({"NewApi", "Override"})
@Keep
class ImeSyncDeferringInsetsCallback {
  private final int deferredInsetTypes = WindowInsets.Type.ime();
  private View view;
  private WindowInsets lastWindowInsets;
  private AnimationCallback animationCallback;
  private InsetsListener insetsListener;
  private ImeVisibilityListener imeVisibilityListener;

  // True when an animation that matches deferredInsetTypes is active.
  //
  // While this is active, this class will capture the initial window inset
  // sent into lastWindowInsets by flagging needsSave to true, and will hold
  // onto the intitial inset until the animation is completed, when it will
  // re-dispatch the inset change.
  private boolean animating = false;
  // When an animation begins, android sends a WindowInset with the final
  // state of the animation. When needsSave is true, we know to capture this
  // initial WindowInset.
  //
  // Certain actions, like dismissing the keyboard, can trigger multiple
  // animations that are slightly offset in start time. To capture the
  // correct final insets in these situations we update needsSave to true
  // in each onPrepare callback, so that we save the latest final state
  // to apply in onEnd.
  private boolean needsSave = false;

  // NX lifecycle patch: only animations belonging to this visible host may defer insets.
  private final Set<WindowInsetsAnimation> activeAnimations =
      Collections.newSetFromMap(new IdentityHashMap<>());
  private boolean hostStopped = false;
  private Activity activity;
  private ViewTreeObserver observedTree;
  private final ViewTreeObserver.OnWindowFocusChangeListener focusListener = hasFocus -> {
    if (hasFocus && !hostStopped) view.requestApplyInsets();
  };
  private final View.OnAttachStateChangeListener attachListener =
      new View.OnAttachStateChangeListener() {
        @Override public void onViewAttachedToWindow(View v) {
          observeWindow();
          v.requestApplyInsets();
        }
        @Override public void onViewDetachedFromWindow(View v) {
          cancelDeferral();
          forgetWindow();
        }
      };
  private final Application.ActivityLifecycleCallbacks lifecycle =
      new Application.ActivityLifecycleCallbacks() {
        @Override public void onActivityStopped(Activity a) {
          if (a == activity) {
            hostStopped = true;
            cancelDeferral();
          }
        }
        @Override public void onActivityStarted(Activity a) {
          if (a == activity) {
            hostStopped = false;
            view.requestApplyInsets();
          }
        }
        @Override public void onActivityCreated(Activity a, Bundle b) {}
        @Override public void onActivityResumed(Activity a) {}
        @Override public void onActivityPaused(Activity a) {}
        @Override public void onActivitySaveInstanceState(Activity a, Bundle b) {}
        @Override public void onActivityDestroyed(Activity a) {}
      };

  private void cancelDeferral() {
    activeAnimations.clear();
    animating = false;
    needsSave = false;
    lastWindowInsets = null;
  }

  private boolean canAnimate() {
    return !hostStopped && view.isAttachedToWindow() && view.isShown();
  }

  private void observeWindow() {
    forgetWindow();
    observedTree = view.getViewTreeObserver();
    observedTree.addOnWindowFocusChangeListener(focusListener);
  }

  private void forgetWindow() {
    if (observedTree != null && observedTree.isAlive()) {
      observedTree.removeOnWindowFocusChangeListener(focusListener);
    }
    observedTree = null;
  }

  ImeSyncDeferringInsetsCallback(@NonNull View view) {
    this.view = view;
    this.animationCallback = new AnimationCallback();
    this.insetsListener = new InsetsListener();
  }

  // Add this object's event listeners to its view.
  void install() {
    view.setWindowInsetsAnimationCallback(animationCallback);
    view.setOnApplyWindowInsetsListener(insetsListener);
    Context context = view.getContext();
    while (context instanceof ContextWrapper) {
      if (context instanceof Activity) {
        activity = (Activity) context;
        activity.getApplication().registerActivityLifecycleCallbacks(lifecycle);
        break;
      }
      Context base = ((ContextWrapper) context).getBaseContext();
      if (base == context) break;
      context = base;
    }
    view.addOnAttachStateChangeListener(attachListener);
    if (view.isAttachedToWindow()) observeWindow();
  }

  // Remove this object's event listeners from its view.
  void remove() {
    cancelDeferral();
    forgetWindow();
    view.removeOnAttachStateChangeListener(attachListener);
    if (activity != null) {
      activity.getApplication().unregisterActivityLifecycleCallbacks(lifecycle);
      activity = null;
    }
    view.setWindowInsetsAnimationCallback(null);
    view.setOnApplyWindowInsetsListener(null);
  }

  // Set a listener to be notified when the IME visibility changes.
  void setImeVisibilityListener(ImeVisibilityListener imeVisibilityListener) {
    this.imeVisibilityListener = imeVisibilityListener;
  }

  @VisibleForTesting
  View.OnApplyWindowInsetsListener getInsetsListener() {
    return insetsListener;
  }

  @VisibleForTesting
  WindowInsetsAnimation.Callback getAnimationCallback() {
    return animationCallback;
  }

  @VisibleForTesting
  ImeVisibilityListener getImeVisibilityListener() {
    return imeVisibilityListener;
  }

  // WindowInsetsAnimation.Callback was introduced in API level 30.  The callback
  // subclass is separated into an inner class in order to avoid warnings from
  // the Android class loader on older platforms.
  @Keep
  private class AnimationCallback extends WindowInsetsAnimation.Callback {
    AnimationCallback() {
      super(WindowInsetsAnimation.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE);
    }

    @Override
    public void onPrepare(WindowInsetsAnimation animation) {
      if (!canAnimate()) {
        cancelDeferral();
        return;
      }
      if ((animation.getTypeMask() & deferredInsetTypes) != 0) {
        activeAnimations.add(animation);
        needsSave = true;
        animating = true;
      }
    }

    @Override
    public WindowInsets onProgress(
        WindowInsets insets, List<WindowInsetsAnimation> runningAnimations) {
      if (!canAnimate()) {
        cancelDeferral();
        return insets;
      }
      if (!animating || needsSave || lastWindowInsets == null) {
        return insets;
      }
      boolean matching = false;
      for (WindowInsetsAnimation animation : runningAnimations) {
        if (activeAnimations.contains(animation)) {
          matching = true;
          continue;
        }
      }
      if (!matching) {
        return insets;
      }

      // Pre 15, the IME insets include the height of the navigation bar. If the app
      // isn't laid out behind the navigation bar, this causes the IME insets to be too large during
      // the animation.  To fix this, we subtract the navigationBars bottom inset if the system UI
      // flags for laying out behind the navigation bar aren't present.
      int excludedInsets = 0;
      int systemUiFlags = view.getWindowSystemUiVisibility();
      if (Build.VERSION.SDK_INT < API_LEVELS.API_35) {
        if ((systemUiFlags & View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION) == 0
            && (systemUiFlags & View.SYSTEM_UI_FLAG_HIDE_NAVIGATION) == 0) {
          excludedInsets = insets.getInsets(WindowInsets.Type.navigationBars()).bottom;
        }
      }

      WindowInsets.Builder builder = new WindowInsets.Builder(lastWindowInsets);
      Insets newImeInsets =
          Insets.of(
              0, 0, 0, Math.max(insets.getInsets(deferredInsetTypes).bottom - excludedInsets, 0));
      builder.setInsets(deferredInsetTypes, newImeInsets);

      // Directly call onApplyWindowInsets of the view as we do not want to pass through
      // the onApplyWindowInsets defined in this class, which would consume the insets
      // as if they were a non-animation inset change and cache it for re-dispatch in
      // onEnd instead.
      view.onApplyWindowInsets(builder.build());
      return insets;
    }

    @Override
    public void onEnd(WindowInsetsAnimation animation) {
      // An interrupted animation must not end a newer one or replay old insets.
      if (!activeAnimations.remove(animation)) return;
      if (animating && activeAnimations.isEmpty()) {
        // If we deferred the IME insets and an IME animation has finished, we need to reset
        // the flags
        animating = false;
        needsSave = false;

        // And finally dispatch the deferred insets to the view now.
        // Ideally we would just call view.requestApplyInsets() and let the normal dispatch
        // cycle happen, but this happens too late resulting in a visual flicker.
        // Instead we manually dispatch the most recent WindowInsets to the view.
        if (lastWindowInsets != null && view != null) {
          view.dispatchApplyWindowInsets(lastWindowInsets);
        }
      }
      WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(view);
      if (insets != null && imeVisibilityListener != null) {
        boolean imeVisible = insets.isVisible(WindowInsetsCompat.Type.ime());
        imeVisibilityListener.onImeVisibilityChanged(imeVisible);
      }
    }
  }

  private class InsetsListener implements View.OnApplyWindowInsetsListener {
    @Override
    public WindowInsets onApplyWindowInsets(View view, WindowInsets windowInsets) {
      ImeSyncDeferringInsetsCallback.this.view = view;
      if (!canAnimate()) {
        // Android can dispatch the final inset after onPrepare but never deliver
        // onEnd once FlutterView becomes GONE. Apply that authoritative value.
        cancelDeferral();
        return view.onApplyWindowInsets(windowInsets);
      }
      if (needsSave) {
        // Store the view and insets for us in onEnd() below. This captured inset
        // is not part of the animation and instead, represents the final state
        // of the inset after the animation is completed. Thus, we defer the processing
        // of this WindowInset until the animation completes.
        lastWindowInsets = windowInsets;
        needsSave = false;
      }
      if (animating) {
        // While animation is running, we consume the insets to prevent disrupting
        // the animation, which skips this implementation and calls the view's
        // onApplyWindowInsets directly to avoid being consumed here.
        return WindowInsets.CONSUMED;
      }

      // If no animation is happening, pass the insets on to the view's own
      // inset handling.
      return view.onApplyWindowInsets(windowInsets);
    }
  }

  // Listener for IME visibility changes.
  public interface ImeVisibilityListener {
    void onImeVisibilityChanged(boolean visible);
  }
}
