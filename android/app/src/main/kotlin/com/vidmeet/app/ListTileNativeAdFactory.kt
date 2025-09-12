package com.vidmeet.app

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import com.vidmeet.app.R

class ListTileNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.list_tile_native_ad, null, false) as NativeAdView

        // Headline
        val headlineView = adView.findViewById<TextView>(R.id.tv_list_tile_native_ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        // Body
        val bodyView = adView.findViewById<TextView>(R.id.tv_list_tile_native_ad_body)
        if (nativeAd.body == null) {
            bodyView.visibility = View.GONE
        } else {
            bodyView.text = nativeAd.body
            bodyView.visibility = View.VISIBLE
        }
        adView.bodyView = bodyView

        // Icon
        val iconView = adView.findViewById<ImageView>(R.id.iv_list_tile_native_ad_icon)
        if (nativeAd.icon == null) {
            iconView.visibility = View.GONE
        } else {
            iconView.setImageDrawable(nativeAd.icon?.drawable)
            iconView.visibility = View.VISIBLE
        }
        adView.iconView = iconView

        // Attribution label handling
        val attributionSmall = adView.findViewById<TextView>(R.id.tv_list_tile_native_ad_attribution_small)
        attributionSmall.visibility = View.VISIBLE

        val attributionLarge = adView.findViewById<TextView>(R.id.tv_list_tile_native_ad_attribution_large)
        attributionLarge.visibility = View.GONE

        adView.setNativeAd(nativeAd)
        return adView
    }
}