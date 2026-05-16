import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

const Color accentColor = Color(0xFF3ECF8E);

class AnexoCompanyItem {
  final int id;
  final String legalName;
  final String agreementNumber;
  final String agreementDate;
  final int? agreementId;

  AnexoCompanyItem({
    required this.id,
    required this.legalName,
    required this.agreementNumber,
    required this.agreementDate,
    required this.agreementId,
  });

  factory AnexoCompanyItem.fromJson(Map<String, dynamic> json) {
    final agreementJson = json['agreement'] as Map<String, dynamic>?;

    return AnexoCompanyItem(
      id: json['id'],
      legalName: json['legalName'] ?? '',
      agreementNumber: agreementJson?['number'] ?? '',
      agreementDate: agreementJson?['signDate'] ?? '',
      agreementId: agreementJson?['id'],
    );
  }
}

class PracticeStudentItem {
  final int id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String courseName;
  final String email;

  PracticeStudentItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.courseName,
    required this.email,
  });

  factory PracticeStudentItem.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>?;

    final firstName = (json['firstName'] ?? '').toString().trim();
    final lastName = (json['lastName'] ?? '').toString().trim();

    return PracticeStudentItem(
      id: (json['id'] as num).toInt(),
      firstName: firstName,
      lastName: lastName,
      fullName: '$firstName $lastName'.trim().isEmpty
          ? '—'
          : '$firstName $lastName'.trim(),
      courseName: (course?['name'] ?? '').toString().trim(),
      email: (json['email'] ?? '').toString().trim(),
    );
  }
}

class PracticeItem {
  final int id;
  final String studentNames;
  final String companyName;
  final String cycleName;
  final String startDate;
  final String endDate;
  final List<String> studentNameList;
  final List<PracticeStudentItem> students;
  final int? agreementId;
  final String agreementNumber;

  PracticeItem({
    required this.id,
    required this.studentNames,
    required this.companyName,
    required this.cycleName,
    required this.startDate,
    required this.endDate,
    required this.studentNameList,
    required this.students,
    required this.agreementId,
    required this.agreementNumber,
  });

  factory PracticeItem.fromJson(Map<String, dynamic> json) {
    final company = json['company'] as Map<String, dynamic>?;
    final agreement = company?['agreement'] as Map<String, dynamic>?;

    final studentsJson =
        (json['students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    final students =
    studentsJson.map((s) => PracticeStudentItem.fromJson(s)).toList();

    final namesList =
    students.map((s) => s.fullName).where((n) => n.isNotEmpty).toList();

    final nombresAlumnos = namesList.join(', ');

    final ciclo = students
        .map((s) => s.courseName)
        .where((n) => n.isNotEmpty)
        .toSet()
        .join(', ');

    return PracticeItem(
      students: students,
      studentNameList: namesList,
      id: (json['id'] as num).toInt(),
      studentNames: nombresAlumnos.isEmpty ? '—' : nombresAlumnos,
      companyName:
      (company?['legalName'] ?? company?['name'] ?? '—').toString(),
      cycleName: ciclo.isEmpty ? '—' : ciclo,
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
      agreementId: agreement?['id'] as int?,
      agreementNumber: (agreement?['number'] ?? '').toString(),
    );
  }
}

class AnexosEmpresasPage extends StatefulWidget {
  final String jwt;

  const AnexosEmpresasPage({super.key, required this.jwt});

  @override
  State<AnexosEmpresasPage> createState() => _AnexosEmpresasPageState();
}

class _AnexosEmpresasPageState extends State<AnexosEmpresasPage> {
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
                  icon: Icon(Icons.description_outlined),
                  text: 'Anexos convenios',
                ),
                Tab(
                  icon: Icon(Icons.assignment_outlined),
                  text: 'Anexos prácticas',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AnexosConveniosTab(jwt: widget.jwt),
                _AnexosPracticasTab(jwt: widget.jwt),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnexosConveniosTab extends StatefulWidget {
  final String jwt;

  const _AnexosConveniosTab({required this.jwt});

  @override
  State<_AnexosConveniosTab> createState() => _AnexosConveniosTabState();
}

class _AnexosConveniosTabState extends State<_AnexosConveniosTab> {
  List<AnexoCompanyItem> empresas = [];
  bool cargando = true;
  int? descargandoCompanyId;

  @override
  void initState() {
    super.initState();
    cargarEmpresas();
  }

  Future<void> cargarEmpresas() async {
    setState(() => cargando = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/companies'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          empresas =
              data.map((json) => AnexoCompanyItem.fromJson(json)).toList();
          cargando = false;
        });
      } else {
        setState(() => cargando = false);
        _showError('Error al cargar empresas: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => cargando = false);
      _showError('Error de conexión: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Documento descargado correctamente'),
        backgroundColor: accentColor,
      ),
    );
  }

  String formatearFecha(String fechaIso) {
    if (fechaIso.trim().isEmpty) return '-';
    try {
      final fecha = DateTime.parse(fechaIso);
      return '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year}';
    } catch (_) {
      return fechaIso;
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

  String _extraerNombreArchivo(
      Map<String, String> headers,
      String fallbackFileName,
      ) {
    final contentDisposition = headers['content-disposition'];

    if (contentDisposition == null || contentDisposition.trim().isEmpty) {
      return fallbackFileName;
    }

    final utf8Match = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
        .firstMatch(contentDisposition);
    if (utf8Match != null && utf8Match.group(1) != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final normalMatch = RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
        .firstMatch(contentDisposition);
    if (normalMatch != null && normalMatch.group(1) != null) {
      return normalMatch.group(1)!;
    }

    return fallbackFileName;
  }

  Future<void> _descargarArchivoBytes({
    required Uri url,
    required String fallbackFileName,
    String? fallbackContentType,
  }) async {
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.jwt}',
        'Accept': '*/*',
      },
    );

    if (response.statusCode == 200) {
      final finalFileName =
      _extraerNombreArchivo(response.headers, fallbackFileName);

      final contentType = response.headers['content-type'] ??
          fallbackContentType ??
          'application/octet-stream';

      final bytes = Uint8List.fromList(response.bodyBytes);

      final blob = web.Blob(
        [bytes.buffer.toJS].toJS,
        web.BlobPropertyBag(type: contentType),
      );

      final downloadUrl = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = downloadUrl
        ..download = finalFileName
        ..style.display = 'none';

      web.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(downloadUrl);

      _showSuccess('ok');
    } else {
      _showError(
        response.body.isNotEmpty
            ? 'Error al descargar archivo: ${response.body}'
            : 'Error al descargar archivo: ${response.statusCode}',
      );
    }
  }

  Future<void> descargarConvenio(AnexoCompanyItem empresa) async {
    if (empresa.agreementId == null) {
      _showError('La empresa no tiene convenio asociado');
      return;
    }

    setState(() => descargandoCompanyId = empresa.id);

    try {
      await _descargarArchivoBytes(
        url: Uri.parse(
          'http://localhost:8080/api/agreements/${empresa.agreementId}/anexo',
        ),
        fallbackFileName:
        'convenio_${empresa.agreementNumber.isEmpty ? empresa.legalName : empresa.agreementNumber}.docx',
        fallbackContentType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } catch (e) {
      _showError('Error de conexión al descargar convenio: $e');
    } finally {
      setState(() => descargandoCompanyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (empresas.isEmpty) {
      return Center(
        child: Text(
          'No hay empresas con convenio.',
          style: TextStyle(color: mutedTextColor(context)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1450),
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
                'Anexos de convenios',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Descarga el convenio generado para cada empresa.',
                style: TextStyle(color: mutedTextColor(context)),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nombre empresa')),
                    DataColumn(label: Text('Nº convenio')),
                    DataColumn(label: Text('Fecha convenio')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: empresas.map((empresa) {
                    final tieneConvenio =
                        empresa.agreementNumber.trim().isNotEmpty &&
                            empresa.agreementId != null;

                    return DataRow(cells: [
                      DataCell(Text(empresa.legalName)),
                      DataCell(Text(
                        empresa.agreementNumber.isEmpty
                            ? '-'
                            : empresa.agreementNumber,
                      )),
                      DataCell(Text(formatearFecha(empresa.agreementDate))),
                      DataCell(
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tieneConvenio
                                ? accentColor
                                : Colors.grey.shade400,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: !tieneConvenio ||
                              descargandoCompanyId == empresa.id
                              ? null
                              : () => descargarConvenio(empresa),
                          icon: descargandoCompanyId == empresa.id
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black),
                            ),
                          )
                              : const Icon(Icons.download_outlined),
                          label: Text(
                            descargandoCompanyId == empresa.id
                                ? 'Generando...'
                                : 'Descargar convenio',
                          ),
                        ),
                      ),
                    ]);
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

class _AnexosPracticasTab extends StatefulWidget {
  final String jwt;

  const _AnexosPracticasTab({required this.jwt});

  @override
  State<_AnexosPracticasTab> createState() => _AnexosPracticasTabState();
}

class _AnexosPracticasTabState extends State<_AnexosPracticasTab> {
  List<PracticeItem> practicas = [];
  bool cargando = true;
  int? descargandoPracticeId;
  String? descargandoTipo;
  int? descargandoStudentId;
  final Set<int> practicasExpandidas = {};

  String? cicloSeleccionado;
  List<String> ciclosDisponibles = [];

  @override
  void initState() {
    super.initState();
    cargarPracticas();
  }

  Future<void> cargarPracticas() async {
    setState(() => cargando = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/practices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final lista = data.map((json) => PracticeItem.fromJson(json)).toList();

        final setCiclos = <String>{};
        for (final p in lista) {
          for (final c in p.students.map((s) => s.courseName)) {
            final ciclo = c.trim();
            if (ciclo.isNotEmpty) {
              setCiclos.add(ciclo);
            }
          }
        }

        setState(() {
          practicas = lista;
          ciclosDisponibles = setCiclos.toList()..sort();
          cicloSeleccionado = null;
          cargando = false;
        });
      } else {
        setState(() => cargando = false);
        _showError('Error al cargar prácticas: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => cargando = false);
      _showError('Error de conexión: $e');
    }
  }

  List<PracticeItem> get practicasFiltradas {
    if (cicloSeleccionado == null || cicloSeleccionado!.trim().isEmpty) {
      return practicas;
    }

    return practicas.where((p) {
      return p.students.any((s) => s.courseName == cicloSeleccionado);
    }).toList();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: accentColor),
    );
  }

  String formatearFecha(String fechaIso) {
    if (fechaIso.trim().isEmpty) return '-';
    try {
      final fecha = DateTime.parse(fechaIso);
      return '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year}';
    } catch (_) {
      return fechaIso;
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

  Color innerCardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111720)
          : const Color(0xFFF8FAFC);

  String _extraerNombreArchivo(
      Map<String, String> headers,
      String fallbackFileName,
      ) {
    final contentDisposition = headers['content-disposition'];

    if (contentDisposition == null || contentDisposition.trim().isEmpty) {
      return fallbackFileName;
    }

    final utf8Match = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
        .firstMatch(contentDisposition);
    if (utf8Match != null && utf8Match.group(1) != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final normalMatch = RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
        .firstMatch(contentDisposition);
    if (normalMatch != null && normalMatch.group(1) != null) {
      return normalMatch.group(1)!;
    }

    return fallbackFileName;
  }

  Future<void> _descargarArchivoBytes({
    required Uri url,
    required String fallbackFileName,
    String? fallbackContentType,
  }) async {
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.jwt}',
        'Accept': '*/*',
      },
    );

    if (response.statusCode == 200) {
      final finalFileName =
      _extraerNombreArchivo(response.headers, fallbackFileName);

      final contentType = response.headers['content-type'] ??
          fallbackContentType ??
          'application/octet-stream';

      final bytes = Uint8List.fromList(response.bodyBytes);

      final blob = web.Blob(
        [bytes.buffer.toJS].toJS,
        web.BlobPropertyBag(type: contentType),
      );

      final downloadUrl = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = downloadUrl
        ..download = finalFileName
        ..style.display = 'none';

      web.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(downloadUrl);

      _showSuccess('Documento descargado correctamente');
    } else {
      _showError(
        response.body.isNotEmpty
            ? 'Error al descargar archivo: ${response.body}'
            : 'Error al descargar archivo: ${response.statusCode}',
      );
    }
  }

  bool _tieneUnSoloAlumno(PracticeItem p) => p.students.length == 1;

  bool _tieneVariosAlumnos(PracticeItem p) => p.students.length > 1;

  void _toggleExpandir(int practiceId) {
    setState(() {
      if (practicasExpandidas.contains(practiceId)) {
        practicasExpandidas.remove(practiceId);
      } else {
        practicasExpandidas.add(practiceId);
      }
    });
  }

  Future<void> _descargarAnexo1(PracticeItem p) async {
    if (p.agreementId == null) {
      _showError('La práctica no tiene convenio asociado');
      return;
    }

    setState(() {
      descargandoPracticeId = p.id;
      descargandoTipo = '1';
      descargandoStudentId = null;
    });

    try {
      await _descargarArchivoBytes(
        url: Uri.parse(
          'http://localhost:8080/api/agreements/${p.agreementId}/anexo',
        ),
        fallbackFileName:
        'convenio_${p.agreementNumber.isEmpty ? p.companyName : p.agreementNumber}.docx',
        fallbackContentType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } catch (e) {
      _showError('Error de conexión al descargar el anexo 1: $e');
    } finally {
      setState(() {
        descargandoPracticeId = null;
        descargandoTipo = null;
      });
    }
  }

  Future<void> _descargarAnexoPractica(
      PracticeItem p,
      String tipo,
      String endpointSuffix,
      ) async {
    setState(() {
      descargandoPracticeId = p.id;
      descargandoTipo = tipo;
      descargandoStudentId = null;
    });

    try {
      await _descargarArchivoBytes(
        url: Uri.parse(
          'http://localhost:8080/api/practices/${p.id}/$endpointSuffix',
        ),
        fallbackFileName: 'practica_${p.id}_anexo_$tipo.docx',
        fallbackContentType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } catch (e) {
      _showError('Error de conexión al descargar el anexo $tipo: $e');
    } finally {
      setState(() {
        descargandoPracticeId = null;
        descargandoTipo = null;
        descargandoStudentId = null;
      });
    }
  }

  Future<void> _descargarAnexoAlumno(
      PracticeItem p,
      PracticeStudentItem student,
      String tipo,
      ) async {
    setState(() {
      descargandoPracticeId = p.id;
      descargandoTipo = tipo;
      descargandoStudentId = student.id;
    });

    try {
      late final Uri url;

      if (tipo == '6') {
        url = Uri.parse(
          'http://localhost:8080/api/practices/${p.id}/anexo6?studentId=${student.id}',
        );
      } else if (tipo == '8') {
        url = Uri.parse(
          'http://localhost:8080/api/practices/${p.id}/anexo8?studentId=${student.id}',
        );
      } else if (tipo == '9') {
        url = Uri.parse(
          'http://localhost:8080/api/practices/${p.id}/anexo9?studentId=${student.id}',
        );
      } else {
        throw Exception('Tipo de anexo no soportado: $tipo');
      }

      await _descargarArchivoBytes(
        url: url,
        fallbackFileName:
        'Anexo${tipo}_${student.lastName}_${student.firstName}.docx',
        fallbackContentType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } catch (e) {
      _showError('Error de conexión al descargar el anexo $tipo: $e');
    } finally {
      setState(() {
        descargandoPracticeId = null;
        descargandoTipo = null;
        descargandoStudentId = null;
      });
    }
  }

  Widget _buildBotonPractica({
    required PracticeItem p,
    required String tipo,
    required String label,
    required String endpointSuffix,
    Color color = accentColor,
    Color textColor = Colors.black,
  }) {
    final isLoading = descargandoPracticeId == p.id &&
        descargandoTipo == tipo &&
        descargandoStudentId == null;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onPressed: isLoading
          ? null
          : () => _descargarAnexoPractica(p, tipo, endpointSuffix),
      child: isLoading
          ? SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      )
          : Text(label),
    );
  }

  Widget _buildBotonAnexo1({
    required PracticeItem p,
    Color color = Colors.greenAccent,
    Color textColor = Colors.black,
  }) {
    final isLoading = descargandoPracticeId == p.id &&
        descargandoTipo == '1' &&
        descargandoStudentId == null;

    final deshabilitado = p.agreementId == null;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: deshabilitado ? Colors.grey.shade300 : color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onPressed: isLoading || deshabilitado ? null : () => _descargarAnexo1(p),
      child: isLoading
          ? SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      )
          : const Text('Anexo 1'),
    );
  }

  Widget _buildBotonAlumno({
    required PracticeItem p,
    required PracticeStudentItem student,
    required String tipo,
    required String label,
    Color color = accentColor,
    Color textColor = Colors.black,
  }) {
    final isLoading = descargandoPracticeId == p.id &&
        descargandoTipo == tipo &&
        descargandoStudentId == student.id;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onPressed:
      isLoading ? null : () => _descargarAnexoAlumno(p, student, tipo),
      child: isLoading
          ? SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      )
          : Text(label),
    );
  }

  Widget _buildFilaAlumnoExpandido(
      PracticeItem p, PracticeStudentItem student) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: innerCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderThemeColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 18),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (student.courseName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      student.courseName,
                      style: TextStyle(color: mutedTextColor(context)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _buildBotonAlumno(
                  p: p,
                  student: student,
                  tipo: '6',
                  label: 'Anexo 6',
                  color: Colors.purple.shade100,
                ),
                _buildBotonAlumno(
                  p: p,
                  student: student,
                  tipo: '8',
                  label: 'Anexo 8',
                  color: Colors.teal.shade100,
                ),
                _buildBotonAlumno(
                  p: p,
                  student: student,
                  tipo: '9',
                  label: 'Anexo 9',
                  color: Colors.orange.shade100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaPractica(PracticeItem p) {
    final expandida = practicasExpandidas.contains(p.id);
    final unSoloAlumno = _tieneUnSoloAlumno(p);
    final variosAlumnos = _tieneVariosAlumnos(p);
    final alumnoUnico = unSoloAlumno ? p.students.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: innerCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderThemeColor(context)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (variosAlumnos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      tooltip:
                      expandida ? 'Plegar alumnos' : 'Desplegar alumnos',
                      onPressed: () => _toggleExpandir(p.id),
                      icon: Icon(
                        expandida ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: Wrap(
                    runSpacing: 10,
                    children: [
                      _buildDatoCabecera('Empresa', p.companyName),
                      _buildDatoCabecera('Ciclo', p.cycleName),
                      _buildDatoCabecera('Inicio', formatearFecha(p.startDate)),
                      _buildDatoCabecera('Fin', formatearFecha(p.endDate)),
                      _buildDatoCabecera(
                        'Alumno/s',
                        p.studentNameList.isEmpty ? '—' : p.studentNames,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          _buildBotonAnexo1(p: p),

                          _buildBotonPractica(
                            p: p,
                            tipo: '4',
                            label: 'Anexo 4',
                            endpointSuffix: 'anexo4',
                            color: Colors.blue.shade100,
                          ),

                          if (unSoloAlumno && alumnoUnico != null)
                            _buildBotonAlumno(
                              p: p,
                              student: alumnoUnico,
                              tipo: '6',
                              label: 'Anexo 6',
                              color: Colors.purple.shade100,
                            ),

                          if (unSoloAlumno && alumnoUnico != null)
                            _buildBotonAlumno(
                              p: p,
                              student: alumnoUnico,
                              tipo: '8',
                              label: 'Anexo 8',
                              color: Colors.teal.shade100,
                            ),

                          if (unSoloAlumno && alumnoUnico != null)
                            _buildBotonAlumno(
                              p: p,
                              student: alumnoUnico,
                              tipo: '9',
                              label: 'Anexo 9',
                              color: Colors.orange.shade100,
                            ),
                        ],
                      ),
                      if (variosAlumnos)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            expandida
                                ? 'Cada alumno tiene sus anexos 6, 8 y 9'
                                : 'Despliega la fila para anexos individuales de cada alumno',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedTextColor(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (variosAlumnos && expandida)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children:
                p.students.map((s) => _buildFilaAlumnoExpandido(p, s)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatoCabecera(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 18),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value.trim().isEmpty ? '—' : value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (practicas.isEmpty) {
      return Center(
        child: Text(
          'No hay prácticas registradas.',
          style: TextStyle(color: mutedTextColor(context)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1450),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderThemeColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Anexos de prácticas',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Filtra por ciclo y despliega una práctica con varios alumnos para descargar el Anexo 6, el Anexo 8 y el Anexo 9 de cada alumno.',
                          style: TextStyle(color: mutedTextColor(context)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      value: cicloSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por ciclo',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todos los ciclos'),
                        ),
                        ...ciclosDisponibles.map(
                              (c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          cicloSeleccionado = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (practicasFiltradas.isEmpty)
                Text(
                  'No hay prácticas para el ciclo seleccionado.',
                  style: TextStyle(color: mutedTextColor(context)),
                )
              else
                ...practicasFiltradas.map(_buildTarjetaPractica),
            ],
          ),
        ),
      ),
    );
  }
}