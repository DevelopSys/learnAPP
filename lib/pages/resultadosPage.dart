import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../model/course.dart';

const Color accentColor = Color(0xFF3ECF8E);

class LearningResultItem {
  final int id;
  final String subjectCode;
  final String subjectName;
  final int number;
  final String description;
  final String? courseName;
  final int? courseId;

  LearningResultItem({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.number,
    required this.description,
    this.courseName,
    this.courseId,
  });

  factory LearningResultItem.fromJson(Map<String, dynamic> json) {
    final courseJson = json['course'] as Map<String, dynamic>?;

    return LearningResultItem(
      id: json['id'],
      subjectCode: json['subjectCode'] ?? '',
      subjectName: json['subjectName'] ?? '',
      number: json['number'] ?? 0,
      description: json['description'] ?? '',
      courseName: courseJson?['name'] ?? '',
      courseId: courseJson?['id'],
    );
  }
}

class ResultadosAprendizajePage extends StatefulWidget {
  final String jwt;

  const ResultadosAprendizajePage({super.key, required this.jwt});

  @override
  State<ResultadosAprendizajePage> createState() =>
      _ResultadosAprendizajePageState();
}

class _ResultadosAprendizajePageState
    extends State<ResultadosAprendizajePage> {
  final GlobalKey<ListadoResultadosTabState> listadoKey =
  GlobalKey<ListadoResultadosTabState>();

  void refrescarListado() {
    listadoKey.currentState?.cargarResultados();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              labelColor: accentColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: accentColor,
              tabs: [
                Tab(
                  icon: Icon(Icons.list_alt_outlined),
                  text: 'Listado',
                ),
                Tab(
                  icon: Icon(Icons.add_circle_outline),
                  text: 'Agregar',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListadoResultadosTab(
                  key: listadoKey,
                  jwt: widget.jwt,
                ),
                AgregarResultadoTab(
                  jwt: widget.jwt,
                  onGuardado: refrescarListado,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListadoResultadosTab extends StatefulWidget {
  final String jwt;

  const ListadoResultadosTab({super.key, required this.jwt});

  @override
  State<ListadoResultadosTab> createState() => ListadoResultadosTabState();
}

class ListadoResultadosTabState extends State<ListadoResultadosTab> {
  List<LearningResultItem> resultados = [];
  List<Course> cursos = [];

  int? cursoFiltroId;
  final TextEditingController buscarController = TextEditingController();
  String textoBusqueda = '';

  bool cargandoResultados = true;
  bool cargandoCursos = true;
  bool procesando = false;

  @override
  void initState() {
    super.initState();
    cargarInicial();
  }

  @override
  void dispose() {
    buscarController.dispose();
    super.dispose();
  }

  Future<void> cargarInicial() async {
    await Future.wait([
      cargarResultados(),
      cargarCursos(),
    ]);
  }

  Future<void> cargarResultados() async {
    setState(() {
      cargandoResultados = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/learning-results');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          resultados =
              data.map((json) => LearningResultItem.fromJson(json)).toList();
          cargandoResultados = false;
        });
      } else {
        setState(() {
          cargandoResultados = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar resultados de aprendizaje: ${response.statusCode}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() {
        cargandoResultados = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error de conexión al cargar resultados de aprendizaje: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> cargarCursos() async {
    setState(() {
      cargandoCursos = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/courses');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          cursos = data.map((json) => Course.fromJson(json)).toList();
          cargandoCursos = false;
        });
      } else {
        setState(() {
          cargandoCursos = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar cursos: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() {
        cargandoCursos = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al cargar cursos: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<LearningResultItem> get resultadosFiltrados {
    return resultados.where((item) {
      final coincideCurso =
          cursoFiltroId == null || item.courseId == cursoFiltroId;

      final texto = textoBusqueda.trim().toLowerCase();

      final coincideTexto = texto.isEmpty ||
          item.subjectCode.toLowerCase().contains(texto) ||
          item.subjectName.toLowerCase().contains(texto) ||
          item.description.toLowerCase().contains(texto) ||
          item.number.toString().contains(texto);

      return coincideCurso && coincideTexto;
    }).toList();
  }

  Future<bool> confirmarAccion({
    required String titulo,
    required String mensaje,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    return resultado ?? false;
  }

  Future<void> borrarResultado(int id) async {
    final confirmado = await confirmarAccion(
      titulo: 'Eliminar resultado',
      mensaje: '¿Seguro que quieres eliminar este resultado de aprendizaje?',
    );

    if (!confirmado) return;

    setState(() {
      procesando = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/learning-results/$id');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resultado de aprendizaje eliminado correctamente'),
            backgroundColor: accentColor,
          ),
        );
        await cargarResultados();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error al eliminar resultado: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al eliminar resultado: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        procesando = false;
      });
    }
  }

  Future<void> editarResultado(LearningResultItem item) async {
    final subjectCodeController =
    TextEditingController(text: item.subjectCode);
    final subjectNameController =
    TextEditingController(text: item.subjectName);
    final numberController =
    TextEditingController(text: item.number.toString());
    final descriptionController =
    TextEditingController(text: item.description);

    int? cursoEditadoId = item.courseId;
    final formKey = GlobalKey<FormState>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar resultado de aprendizaje'),
              content: SizedBox(
                width: 550,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: subjectCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Código de módulo',
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el código'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: subjectNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de módulo',
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el nombre del módulo'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: numberController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Número RA',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Introduce el número';
                            }
                            final numero = int.tryParse(value.trim());
                            if (numero == null || numero <= 0) {
                              return 'Número no válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: cursoEditadoId,
                          decoration: const InputDecoration(
                            labelText: 'Curso',
                          ),
                          items: cursos.map((curso) {
                            return DropdownMenuItem<int>(
                              value: curso.id,
                              child: Text(curso.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setStateDialog(() {
                              cursoEditadoId = value;
                            });
                          },
                          validator: (value) =>
                          value == null ? 'Selecciona un curso' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descriptionController,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce la descripción'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmado != true) {
      subjectCodeController.dispose();
      subjectNameController.dispose();
      numberController.dispose();
      descriptionController.dispose();
      return;
    }

    setState(() {
      procesando = true;
    });

    try {
      final url =
      Uri.parse('http://localhost:8080/api/learning-results/${item.id}');

      final body = jsonEncode({
        'subjectCode': subjectCodeController.text.trim(),
        'subjectName': subjectNameController.text.trim(),
        'number': int.parse(numberController.text.trim()),
        'description': descriptionController.text.trim(),
        'courseId': cursoEditadoId,
      });

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwt}',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resultado de aprendizaje actualizado correctamente'),
            backgroundColor: accentColor,
          ),
        );
        await cargarResultados();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar resultado: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al actualizar resultado: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      subjectCodeController.dispose();
      subjectNameController.dispose();
      numberController.dispose();
      descriptionController.dispose();

      setState(() {
        procesando = false;
      });
    }
  }

  Color surfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  Color borderThemeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF263041)
          : const Color(0xFFD7DEE8);

  Color mutedTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.68)
          : Colors.black.withOpacity(0.60);

  @override
  Widget build(BuildContext context) {
    if (cargandoResultados || cargandoCursos) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderThemeColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Listado de resultados de aprendizaje',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Consulta, filtra, busca, edita y elimina resultados de aprendizaje registrados.',
                style: TextStyle(color: mutedTextColor(context)),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final esAncho = constraints.maxWidth > 1100;

                  final filtroCurso = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filtrar por curso'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        value: cursoFiltroId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Todos los cursos',
                          prefixIcon: Icon(Icons.filter_alt_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todos los cursos'),
                          ),
                          ...cursos.map((curso) {
                            return DropdownMenuItem<int?>(
                              value: curso.id,
                              child: Text(curso.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            cursoFiltroId = value;
                          });
                        },
                      ),
                    ],
                  );

                  final buscador = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Buscar'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: buscarController,
                        decoration: InputDecoration(
                          hintText: 'Código, módulo, descripción o número',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: textoBusqueda.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              buscarController.clear();
                              setState(() {
                                textoBusqueda = '';
                              });
                            },
                          )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            textoBusqueda = value;
                          });
                        },
                      ),
                    ],
                  );

                  if (esAncho) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: filtroCurso),
                        const SizedBox(width: 16),
                        Expanded(child: buscador),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      filtroCurso,
                      const SizedBox(height: 16),
                      buscador,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (resultadosFiltrados.isEmpty)
                Text(
                  'No hay resultados de aprendizaje que coincidan con los filtros aplicados.',
                  style: TextStyle(color: mutedTextColor(context)),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Código módulo')),
                      DataColumn(label: Text('Nombre módulo')),
                      DataColumn(label: Text('Nº RA')),
                      DataColumn(label: Text('Descripción')),
                      DataColumn(label: Text('Curso')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: resultadosFiltrados.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(item.subjectCode)),
                          DataCell(Text(item.subjectName)),
                          DataCell(Text(item.number.toString())),
                          DataCell(
                            SizedBox(
                              width: 380,
                              child: Text(
                                item.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(item.courseName ?? 'Sin curso')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar resultado',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: procesando
                                      ? null
                                      : () => editarResultado(item),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar resultado',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: procesando
                                      ? null
                                      : () => borrarResultado(item.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgregarResultadoTab extends StatefulWidget {
  final String jwt;
  final VoidCallback? onGuardado;

  const AgregarResultadoTab({
    super.key,
    required this.jwt,
    this.onGuardado,
  });

  @override
  State<AgregarResultadoTab> createState() => _AgregarResultadoTabState();
}

class _AgregarResultadoTabState extends State<AgregarResultadoTab> {
  final _formKey = GlobalKey<FormState>();

  final subjectCodeController = TextEditingController();
  final subjectNameController = TextEditingController();
  final numberController = TextEditingController();
  final descriptionController = TextEditingController();

  Course? cursoSeleccionado;
  List<Course> cursos = [];

  bool procesandoCsv = false;

  @override
  void initState() {
    super.initState();
    cargarCursos();
  }

  @override
  void dispose() {
    subjectCodeController.dispose();
    subjectNameController.dispose();
    numberController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> cargarCursos() async {
    final url = Uri.parse('http://localhost:8080/api/courses');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.jwt}',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        cursos = data.map((json) => Course.fromJson(json)).toList();
      });
    } else {
      debugPrint('Error cargando cursos: ${response.body}');
    }
  }

  Future<void> guardarResultado() async {
    if (_formKey.currentState!.validate()) {
      final url = Uri.parse('http://localhost:8080/api/learning-results');

      final body = jsonEncode({
        'subjectCode': subjectCodeController.text.trim(),
        'subjectName': subjectNameController.text.trim(),
        'number': int.parse(numberController.text.trim()),
        'description': descriptionController.text.trim(),
        'courseId': cursoSeleccionado?.id,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwt}',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resultado de aprendizaje agregado correctamente'),
            backgroundColor: accentColor,
          ),
        );

        subjectCodeController.clear();
        subjectNameController.clear();
        numberController.clear();
        descriptionController.clear();

        setState(() {
          cursoSeleccionado = null;
        });

        widget.onGuardado?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprueba los datos del formulario'),
          backgroundColor: accentColor,
        ),
      );
    }
  }

  Future<void> subirCsvResultados() async {
    try {
      setState(() {
        procesandoCsv = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          procesandoCsv = false;
        });
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      final fileName = file.name;

      if (bytes == null) {
        setState(() {
          procesandoCsv = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer el contenido del fichero'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final uri = Uri.parse('http://localhost:8080/api/learning-results/upload');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.jwt}'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.body.isNotEmpty
                  ? response.body
                  : 'CSV procesado correctamente',
            ),
            backgroundColor: accentColor,
          ),
        );
        widget.onGuardado?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar CSV: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir CSV: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        procesandoCsv = false;
      });
    }
  }

  Future<void> descargarPlantillaCsv() async {
    try {
      final url = Uri.parse('http://localhost:8080/api/learning-results/template');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        final csv = response.body;
        final bytes = utf8.encode(csv);
        final uint8List = Uint8List.fromList(bytes);

        final data = uint8List.buffer.toJS;
        final blob = web.Blob(
          [data].toJS,
          web.BlobPropertyBag(type: 'text/csv'),
        );
        final downloadUrl = web.URL.createObjectURL(blob);

        final anchor = web.HTMLAnchorElement()
          ..href = downloadUrl
          ..download = 'plantilla_resultados_aprendizaje.csv'
          ..style.display = 'none';

        web.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        web.URL.revokeObjectURL(downloadUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error al descargar plantilla: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al descargar plantilla: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Color surfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  Color borderThemeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF263041)
          : const Color(0xFFD7DEE8);

  Color mutedTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.68)
          : Colors.black.withOpacity(0.60);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderThemeColor(context)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alta de resultado de aprendizaje',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rellena los datos para registrar un resultado de aprendizaje o utiliza un fichero CSV.',
                  style: TextStyle(color: mutedTextColor(context)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: procesandoCsv ? null : subirCsvResultados,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Cargar CSV'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                          Theme.of(context).colorScheme.onSurface,
                          side: BorderSide(color: borderThemeColor(context)),
                        ),
                        onPressed: descargarPlantillaCsv,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Descargar plantilla'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Curso'),
                const SizedBox(height: 8),
                DropdownButtonFormField<Course>(
                  value: cursoSeleccionado,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  decoration: const InputDecoration(
                    hintText: 'Selecciona un curso',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: cursos.map((curso) {
                    return DropdownMenuItem<Course>(
                      value: curso,
                      child: Text(curso.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      cursoSeleccionado = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecciona un curso';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Código de módulo'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: subjectCodeController,
                  decoration: const InputDecoration(
                    hintText: 'Ej: 0485',
                    prefixIcon: Icon(Icons.qr_code_outlined),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Introduce el código de módulo'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text('Nombre de módulo'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: subjectNameController,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Programación',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Introduce el nombre del módulo'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text('Número del resultado'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Ej: 1',
                    prefixIcon: Icon(Icons.format_list_numbered_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce el número';
                    }
                    final numero = int.tryParse(value.trim());
                    if (numero == null || numero <= 0) {
                      return 'Número no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Descripción'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText:
                    'Introduce la descripción del resultado de aprendizaje',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Introduce la descripción'
                      : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: guardarResultado,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      'Agregar resultado de aprendizaje',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}