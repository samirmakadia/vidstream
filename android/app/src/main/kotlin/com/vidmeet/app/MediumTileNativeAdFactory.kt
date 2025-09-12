package com.vidmeet.app

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import com.vidmeet.app.R

class MediumTileNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val container = LayoutInflater.from(context).inflate(R.layout.medium_tile_native_ad, null, false)
        val adView = NativeAdView(context)
        adView.addView(container)

        // Headline
        val headlineView = adView.findViewById<TextView>(R.id.native_ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        // Body
        val bodyView = adView.findViewById<TextView>(R.id.native_ad_body)
        if (nativeAd.body == null) {
            bodyView.visibility = View.GONE
        } else {
            bodyView.text = nativeAd.body
            bodyView.visibility = View.VISIBLE
        }
        adView.bodyView = bodyView

        // Media View
        val mediaView = adView.findViewById<MediaView>(R.id.native_ad_media)
        adView.mediaView = mediaView
        mediaView.setMediaContent(nativeAd.mediaContent)

        // Call to Action
        val ctaButton = adView.findViewById<Button>(R.id.native_ad_call_to_action)
        if (nativeAd.callToAction == null) {
            ctaButton.visibility = View.GONE
        } else {
            ctaButton.text = nativeAd.callToAction
            ctaButton.visibility = View.VISIBLE
        }
        adView.callToActionView = ctaButton

        adView.setNativeAd(nativeAd)
        return adView
    }
}
