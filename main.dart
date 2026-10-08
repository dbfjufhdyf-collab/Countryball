import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';

// TEST ad unit. Asli AdMob banner unit ID yahan badlo (README dekho).
const String kBannerUnit = 'ca-app-pub-3940256099942544/6300978111';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Home()));
}

void paintBall(Canvas c, ui.Image? img, bool fh, bool fv, int rot) {
  const cx = 415.0, cy = 385.0, r = 300.0;
  const ctr = Offset(cx, cy);
  c.save();
  c.translate(cx, cy);
  c.rotate(rot * pi / 2);
  c.scale(fh ? -1 : 1, fv ? -1 : 1);
  c.translate(-cx, -cy);
  c.drawCircle(const Offset(cx - 38, cy + 34), r, Paint()..color = const Color.fromRGBO(0, 0, 0, .32));
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: ctr, radius: r)));
  if (img == null) {
    c.drawCircle(ctr, r, Paint()..color = Colors.white);
  } else {
    final w = img.width.toDouble(), h = img.height.toDouble();
    final s = max(2 * r / w, 2 * r / h);
    c.drawImageRect(img, Rect.fromLTWH(0, 0, w, h),
        Rect.fromCenter(center: ctr, width: w * s, height: h * s),
        Paint()..filterQuality = FilterQuality.high);
  }
  void crescent(double dx, double dy, double rr, double a) {
    c.saveLayer(const Rect.fromLTWH(0, 0, 800, 800), Paint());
    c.drawCircle(ctr, r, Paint()..color = Color.fromRGBO(0, 0, 0, a));
    c.drawCircle(ctr + Offset(dx, dy), rr, Paint()..blendMode = BlendMode.clear);
    c.restore();
  }
  crescent(70, -60, r * .98, .2);
  crescent(34, -28, r * .99, .22);
  c.restore();
  c.drawCircle(ctr, r, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 16
    ..color = Colors.black);
  c.restore();
}

class BallPainter extends CustomPainter {
  final ui.Image? img; final bool fh, fv; final int rot;
  BallPainter(this.img, this.fh, this.fv, this.rot);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 800);
    paintBall(canvas, img, fh, fv, rot);
  }
  @override
  bool shouldRepaint(covariant BallPainter o) => true;
}

class AdBox extends StatefulWidget {
  const AdBox({super.key});
  @override
  State<AdBox> createState() => _AdBoxState();
}

class _AdBoxState extends State<AdBox> {
  BannerAd? ad;
  bool ok = false;
  @override
  void initState() {
    super.initState();
    ad = BannerAd(
      adUnitId: kBannerUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => ok = true),
        onAdFailedToLoad: (a, e) => a.dispose(),
      ),
    )..load();
  }
  @override
  void dispose() { ad?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 50,
      child: ok ? AdWidget(ad: ad!) : const SizedBox.shrink());
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  ui.Image? img;
  bool fh = false, fv = false;
  int rot = 0;

  Future<void> pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final codec = await ui.instantiateImageCodec(await f.readAsBytes());
    final fr = await codec.getNextFrame();
    setState(() => img = fr.image);
  }

  Future<void> save() async {
    if (img == null) return;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.translate(-50, -50);
    paintBall(c, img, fh, fv, rot);
    final out = await rec.endRecording().toImage(700, 700);
    final bytes = (await out.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    String msg = 'Gallery me save ho gaya';
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(bytes, name: 'countryball_${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      msg = 'Save nahi hua: $e';
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget btn(String t, VoidCallback f, {bool main = false}) => ElevatedButton(
      onPressed: f,
      style: ElevatedButton.styleFrom(
          backgroundColor: main ? const Color(0xFF0B6A31) : null,
          foregroundColor: main ? Colors.white : null),
      child: Text(t));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const AdBox(),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(painter: BallPainter(img, fh, fv, rot)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              btn('Flag chuno', pick, main: true),
              btn('Left-Right flip', () => setState(() => fh = !fh)),
              btn('Upar-Niche flip', () => setState(() => fv = !fv)),
              btn('Ghumao 90°', () => setState(() => rot = (rot + 1) % 4)),
              btn('PNG save karo', save, main: true),
            ]),
          ),
          const AdBox(),
        ]),
      ),
    );
  }
}
