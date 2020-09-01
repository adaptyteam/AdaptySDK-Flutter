package com.adapty.flutter.models

data class AdaptyProduct(
        val id: String,
        val title: String,
        val description: String,
        val price: String,
        val localizedPrice: String,
        val currency: String
)