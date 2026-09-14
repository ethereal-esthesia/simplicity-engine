package dev.simplicityengine.hellopixel;

import org.libsdl.app.SDLActivity;

public final class HelloPixelActivity extends SDLActivity {
    @Override
    protected String[] getArguments() {
        if (BuildConfig.DEBUG && getIntent().getBooleanExtra("menu_self_test", false)) {
            return new String[]{"--self-test"};
        }
        return new String[0];
    }
}
