# تصدير Android

لا يتضمن المستودع قوالب تصدير Godot الضخمة أو Android SDK/NDK أو مفتاح توقيع إنتاجيًا. ينزّل GitHub Actions إصدار Godot 4.4.1 وقوالب Android المطابقة، ويهيئ Java 17 وAndroid SDK API 35 وNDK r23c عند كل بناء.

اسم الإعداد في `export_presets.cfg` هو `Android`. يستهدف Android 9/API 28 أو أحدث، ويصدر APK موقّعًا بمفتاح debug للاختبار على جهاز. **هذا المفتاح ليس لإصدار Google Play.** للنشر، استخدم مفتاح إصدار تملكه وخزّنه كسر GitHub Actions؛ لا تضع ملف المفتاح أو كلمة مروره في المستودع.

بعد نجاح Workflow، نزّل الأثر `Velocity-Rush-3D-Android-APK` لتجد `VelocityRush3D.apk`. وتوجد سجلات الاستيراد والتشغيل والتصدير في أثر منفصل باسم `Velocity-Rush-3D-Diagnostics`.
