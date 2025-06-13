import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// three.js core
import 'package:three_js_core/three_js_core.dart';
// STL loader
import 'package:three_js_simple_loaders/three_js_simple_loaders.dart';
// Orbit controls
import 'package:three_js_controls/three_js_controls.dart';

// HTML interop
import 'package:universal_html/html.dart' as html;
import 'dart:ui_web' show platformViewRegistry;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'STL Viewer',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
        ),
        home: const ViewerPage(),
      );
}

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> with SingleTickerProviderStateMixin {
  late ThreeJS threeJs;
  OrbitControls? controls;
  Mesh? _currentMesh;

  bool _isSceneReady = false;
  late Ticker _ticker;
  final String _viewId = 'visualizador-stl-view';

  final List<String> _models = [
    'Basketball_Stand.stl',
    // Adicione outros modelos .stl aqui
  ];
  String? _currentModel;

  @override
  void initState() {
    super.initState();
    _currentModel = _models.first;

    threeJs = ThreeJS(
      onSetupComplete: _onSetupComplete,
      setup: _setupScene,
    );

    _ticker = createTicker((_) => _animate());
  }

  void _onSetupComplete() {
    // Registra o canvas do Three.js para o Flutter Web usando universal_html
    platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => threeJs.domElement as html.HtmlElement,
    );

    // Carrega o modelo e inicia o loop de animação
    _loadModel(_currentModel!).then((_) {
      setState(() => _isSceneReady = true);
      _ticker.start();
    });
  }

  void _animate() {
    controls?.update();
    threeJs.renderer?.render(threeJs.scene, threeJs.camera);
  }

  @override
  void dispose() {
    _ticker.dispose();
    threeJs.dispose();
    super.dispose();
  }

  Future<void> _setupScene() async {
    // Câmera
    threeJs.camera = PerspectiveCamera(
      75,
      threeJs.width / threeJs.height,
      0.1,
      1000,
    )..position.setValues(0, 100, 200);

    // Cena + Luz
    threeJs.scene = Scene()
      ..background = Color(0xfff0f0f0)
      ..add(AmbientLight(0xffffff, 1.5));
    threeJs.scene.add(PointLight(0xffffff, 300)..position.setValues(50, 50, 50));

    // Tamanho do renderer
    threeJs.renderer!.setSize(threeJs.width, threeJs.height);

    // Controles de órbita usando o mesmo DOMElement
    controls = OrbitControls(
      threeJs.camera,
      threeJs.domElement as GlobalKey<PeripheralsState>,
    )
      ..enableDamping = true
      ..dampingFactor = 0.05;
  }

  Future<void> _loadModel(String filename) async {
    if (_currentMesh != null) {
      threeJs.scene.remove(_currentMesh!);
      _currentMesh!.geometry?.dispose();
      _currentMesh!.material?.dispose();
      _currentMesh = null;
    }

    final loader = STLLoader();
    BufferGeometry? geometry;

    try {
      geometry = (await loader.fromAsset('assets/models/$filename')) as BufferGeometry?;
    } catch (e) {
      debugPrint('Erro ao carregar o modelo: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar \$filename')),
        );
      }
      return;
    }

    if (geometry == null) return;

    geometry.center();
    final material = MeshNormalMaterial();
    final mesh = Mesh(geometry, material);
    _currentMesh = mesh;
    threeJs.scene.add(mesh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualizador de STL'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.indigo, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _isSceneReady
                    ? HtmlElementView(viewType: _viewId)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: _models.map((m) {
                return ChoiceChip(
                  label: Text(m.replaceAll('', ' ').replaceAll('.stl', '')),
                  selected: m == _currentModel,
                  onSelected: (yes) {
                    if (yes && m != _currentModel) {
                      setState(() => _currentModel = m);
                      _loadModel(m);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
