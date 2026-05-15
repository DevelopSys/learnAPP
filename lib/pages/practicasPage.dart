import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const Color accentColor = Color(0xFF3ECF8E);

// FORMATOS DE FECHA Y HORA
final DateFormat backendFormat = DateFormat('yyyy-MM-dd');
final DateFormat uiFormat = DateFormat('dd/MM/yyyy');

String formatToUiDate(DateTime date) => uiFormat.format(date);
String formatToBackendDate(DateTime date) => backendFormat.format(date);

DateTime? parseUiDate(String value) {
  try {
    return uiFormat.parseStrict(value);
  } catch (e) {
    return null;
  }
}

// MODELOS
class PracticeItem {
  final int id;
  final String companyName;
  final String agreementNumber;
  final String agreementDate;
  final String traineeName;
  final List<String> studentNames;
  final List<String> studentCourseNames;
  final String workplace;
  final String startDate;
  final String endDate;
  final String schedule;
  final String? startTime;
  final String? endTime;
  final int? totalHours;
  final int? dailyHours;
  final List<int> studentIds;

  PracticeItem({
    required this.id,
    required this.companyName,
    required this.agreementNumber,
    required this.agreementDate,
    required this.traineeName,
    required this.studentNames,
    required this.studentCourseNames,
    required this.workplace,
    required this.startDate,
    required this.endDate,
    required this.schedule,
    this.startTime,
    this.endTime,
    this.totalHours,
    this.dailyHours,
    required this.studentIds,
  });

  factory PracticeItem.fromJson(Map<String, dynamic> json) {
    final companyJson = json['company'] as Map<String, dynamic>?;
    final traineeJson = json['trainee'] as Map<String, dynamic>?;
    final studentsJson = (json['students'] as List<dynamic>?) ?? [];

    final studentNames = <String>[];
    final studentCourseNames = <String>[];
    final studentIds = <int>[];

    for (final s in studentsJson) {
      final m = s as Map<String, dynamic>;
      final name = '${m['firstName']} ${m['lastName']}';
      studentNames.add(name);
      studentIds.add((m['id'] as num).toInt());

      final course = m['course'] as Map<String, dynamic>?;
      if (course != null && course['name'] != null) {
        studentCourseNames.add(course['name'] as String);
      }
    }

    final agreementDateRaw = json['agreementSignDate']?.toString() ?? "";
    String agreementDateUi = agreementDateRaw;
    try {
      if (agreementDateRaw.isNotEmpty) {
        agreementDateUi = formatToUiDate(backendFormat.parse(agreementDateRaw));
      }
    } catch (_) {}

    String startUi = json['startDate']?.toString() ?? "";
    String endUi = json['endDate']?.toString() ?? "";
    try {
      if (startUi.isNotEmpty) startUi = formatToUiDate(backendFormat.parse(startUi));
      if (endUi.isNotEmpty) endUi = formatToUiDate(backendFormat.parse(endUi));
    } catch (_) {}

    return PracticeItem(
      id: json['id'],
      companyName: companyJson?['legalName'] ?? "",
      agreementNumber: json['agreementNumber'] ?? "",
      agreementDate: agreementDateUi,
      traineeName: '${traineeJson?['firstName'] ?? ''} ${traineeJson?['lastName'] ?? ''}'.trim(),
      studentNames: studentNames,
      studentCourseNames: studentCourseNames,
      workplace: json['workplace'] ?? "",
      startDate: startUi,
      endDate: endUi,
      schedule: json['schedule'] ?? "",
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      totalHours: json['totalHours'] as int?,
      dailyHours: json['dailyHours'] as int?,
      studentIds: studentIds,
    );
  }
}

class SimpleStudent {
  final int id;
  final String fullName;
  final String courseName;

  SimpleStudent({required this.id, required this.fullName, required this.courseName});

  factory SimpleStudent.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>?;
    return SimpleStudent(
      id: json['id'],
      fullName: '${json['firstName']} ${json['lastName']}',
      courseName: course?['name']?.toString() ?? "",
    );
  }
}

class SimpleCompany {
  final int id;
  final String legalName;
  final String street;
  final String postalCode;
  final String city;
  final String? province;
  final String? country;

  SimpleCompany({
    required this.id,
    required this.legalName,
    required this.street,
    required this.postalCode,
    required this.city,
    this.province,
    this.country,
  });

  factory SimpleCompany.fromJson(Map<String, dynamic> json) {
    return SimpleCompany(
      id: json['id'],
      legalName: json['legalName'] ?? "",
      street: json['street'] ?? "",
      postalCode: json['postalCode'] ?? "",
      city: json['city'] ?? "",
      province: json['province'],
      country: json['country'],
    );
  }

  String get fullAddress {
    final parts = <String>[street, postalCode, city];
    if (province != null && province!.trim().isNotEmpty) parts.add(province!);
    if (country != null && country!.trim().isNotEmpty) parts.add(country!);
    return parts.where((p) => p.trim().isNotEmpty).join(', ');
  }
}

class SimpleTrainee {
  final int id;
  final String fullName;
  final int companyId;

  SimpleTrainee({required this.id, required this.fullName, required this.companyId});

  factory SimpleTrainee.fromJson(Map<String, dynamic> json) {
    final company = json['company'] as Map<String, dynamic>?;
    return SimpleTrainee(
      id: json['id'],
      fullName: '${json['firstName']} ${json['lastName']}',
      companyId: (company?['id'] as num?)?.toInt() ?? 0,
    );
  }
}

// PÁGINA PRINCIPAL
class PracticasPage extends StatefulWidget {
  final String jwt;
  const PracticasPage({super.key, required this.jwt});

  @override
  State<PracticasPage> createState() => PracticasPageState();
}

class PracticasPageState extends State<PracticasPage> {
  final GlobalKey<ListadoPracticasTabState> listadoKey = GlobalKey<ListadoPracticasTabState>();

  void refrescarListado() {
    listadoKey.currentState?.cargarPracticas();
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
                Tab(icon: Icon(Icons.list_alt_outlined), text: 'Listado'),
                Tab(icon: Icon(Icons.work_outline), text: 'Crear práctica'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListadoPracticasTab(key: listadoKey, jwt: widget.jwt),
                CrearPracticaTab(jwt: widget.jwt, onPracticaCreada: refrescarListado),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// LISTADO
class ListadoPracticasTab extends StatefulWidget {
  final String jwt;
  const ListadoPracticasTab({super.key, required this.jwt});

  @override
  State<ListadoPracticasTab> createState() => ListadoPracticasTabState();
}

class ListadoPracticasTabState extends State<ListadoPracticasTab> {
  List<PracticeItem> practicas = [];
  List<PracticeItem> practicasFiltradas = [];
  bool cargando = true;

  String? cursoSeleccionado;
  List<String> cursosDisponibles = [];

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
        headers: {'Authorization': 'Bearer ${widget.jwt}'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final lista = data.map((json) => PracticeItem.fromJson(json)).toList();

        final setCursos = <String>{};
        for (final p in lista) {
          setCursos.addAll(p.studentCourseNames.where((c) => c.isNotEmpty));
        }

        setState(() {
          practicas = lista;
          cursosDisponibles = setCursos.toList()..sort();
          practicasFiltradas = List.from(practicas);
          cargando = false;
        });
      }
    } catch (e) {
      setState(() => cargando = false);
    }
  }

  void aplicarFiltroCurso(String? curso) {
    setState(() {
      cursoSeleccionado = curso;
      practicasFiltradas = (curso == null || curso.isEmpty)
          ? List.from(practicas)
          : practicas.where((p) => p.studentCourseNames.contains(curso)).toList();
    });
  }

  Future<void> confirmarEliminarPractica(PracticeItem p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar práctica'),
        content: Text('¿Seguro que quieres eliminar la práctica con convenio ${p.agreementNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final res = await http.delete(
        Uri.parse('http://localhost:8080/api/practices/${p.id}'),
        headers: {'Authorization': 'Bearer ${widget.jwt}'},
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        cargarPracticas();
      }
    }
  }

  Future<void> editarPractica(PracticeItem p) async {
    final actualizado = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 900,
          child: PracticeEditDialog(jwt: widget.jwt, practice: p),
        ),
      ),
    );
    if (actualizado == true) cargarPracticas();
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Listado de prácticas', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                  if (cursosDisponibles.isNotEmpty)
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        value: cursoSeleccionado,
                        decoration: const InputDecoration(labelText: 'Filtrar por curso'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos los cursos')),
                          ...cursosDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: aplicarFiltroCurso,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Empresa')),
                    DataColumn(label: Text('Convenio')),
                    DataColumn(label: Text('Alumnos')),
                    DataColumn(label: Text('Curso')),
                    DataColumn(label: Text('Inicio')),
                    DataColumn(label: Text('Fin')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: practicasFiltradas.map((p) {
                    return DataRow(cells: [
                      DataCell(Text(p.companyName)),
                      DataCell(Text(p.agreementNumber)),
                      DataCell(Text(p.studentNames.join(', '))),
                      DataCell(Text(p.studentCourseNames.isNotEmpty ? p.studentCourseNames.first : '-')),
                      DataCell(Text(p.startDate)),
                      DataCell(Text(p.endDate)),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              icon: const Icon(Icons.edit),
                              iconSize: 20,
                              onPressed: () => editarPractica(p),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              iconSize: 20,
                              color: Colors.redAccent,
                              onPressed: () => confirmarEliminarPractica(p),
                            ),
                          ],
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

// DIÁLOGO DE EDICIÓN (Simplificado en la plantilla original)
class PracticeEditDialog extends StatefulWidget {
  final String jwt;
  final PracticeItem practice;
  const PracticeEditDialog({super.key, required this.jwt, required this.practice});

  @override
  State<PracticeEditDialog> createState() => PracticeEditDialogState();
}

class PracticeEditDialogState extends State<PracticeEditDialog> {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Text('Formulario de edición... (Lógica original de edición)'),
    );
  }
}

// CREAR PRÁCTICA
class CrearPracticaTab extends StatefulWidget {
  final String jwt;
  final VoidCallback? onPracticaCreada;

  const CrearPracticaTab({
    super.key,
    required this.jwt,
    this.onPracticaCreada,
  });

  @override
  State<CrearPracticaTab> createState() => CrearPracticaTabState();
}

class CrearPracticaTabState extends State<CrearPracticaTab> {
  final _formKey = GlobalKey<FormState>();

  List<SimpleStudent> alumnos = [];
  List<SimpleCompany> empresas = [];
  List<SimpleTrainee> tutores = [];

  String? filtroCursoAlumnos;
  List<String> cursosAlumnosDisponibles = [];
  List<SimpleTrainee> tutoresFiltrados = [];

  final Set<int> alumnosSeleccionados = {};
  SimpleCompany? empresaSeleccionada;
  SimpleTrainee? tutorSeleccionado;

  final TextEditingController empresaSearchController = TextEditingController();
  final TextEditingController lugarTrabajoController = TextEditingController();
  final TextEditingController fechaInicioController = TextEditingController();
  final TextEditingController fechaFinController = TextEditingController();
  final TextEditingController horarioController = TextEditingController();
  final TextEditingController horasTotalesController = TextEditingController();
  final TextEditingController horasDiariasController = TextEditingController();

  // CONTROLADORES DE HORA POR DEFECTO A LAS 09:00 Y 18:00
  final TextEditingController horaInicioController = TextEditingController(text: "09:00");
  final TextEditingController horaFinController = TextEditingController(text: "18:00");

  DateTime? fechaInicioSeleccionada;
  DateTime? fechaFinSeleccionada;

  // VARIABLES DE HORA POR DEFECTO A LAS 09:00 Y 18:00
  TimeOfDay? horaInicioSeleccionada = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? horaFinSeleccionada = const TimeOfDay(hour: 18, minute: 0);

  bool cargandoDatos = true;
  bool creando = false;
  bool mostrandoSugerenciasEmpresa = false;

  @override
  void initState() {
    super.initState();
    cargarDatosIniciales();
  }

  @override
  void dispose() {
    empresaSearchController.dispose();
    lugarTrabajoController.dispose();
    fechaInicioController.dispose();
    fechaFinController.dispose();
    horarioController.dispose();
    horasTotalesController.dispose();
    horasDiariasController.dispose();
    horaInicioController.dispose();
    horaFinController.dispose();
    super.dispose();
  }

  Future<void> cargarDatosIniciales() async {
    setState(() => cargandoDatos = true);
    try {
      final studentsUrl = Uri.parse('http://localhost:8080/api/students');
      final companiesUrl = Uri.parse('http://localhost:8080/api/companies');
      final traineesUrl = Uri.parse('http://localhost:8080/api/trainees');
      final practicesUrl = Uri.parse('http://localhost:8080/api/practices'); // NUEVO: para filtrar alumnos asignados

      final responses = await Future.wait([
        http.get(studentsUrl, headers: {'Authorization': 'Bearer ${widget.jwt}'}),
        http.get(companiesUrl, headers: {'Authorization': 'Bearer ${widget.jwt}'}),
        http.get(traineesUrl, headers: {'Authorization': 'Bearer ${widget.jwt}'}),
        http.get(practicesUrl, headers: {'Authorization': 'Bearer ${widget.jwt}'}),
      ]);

      final studentsResponse = responses[0];
      final companiesResponse = responses[1];
      final traineesResponse = responses[2];
      final practicesResponse = responses[3];

      if (studentsResponse.statusCode == 200 &&
          companiesResponse.statusCode == 200 &&
          traineesResponse.statusCode == 200 &&
          practicesResponse.statusCode == 200) {

        final studentsData = jsonDecode(studentsResponse.body) as List;
        final companiesData = jsonDecode(companiesResponse.body) as List;
        final traineesData = jsonDecode(traineesResponse.body) as List;
        final practicesData = jsonDecode(practicesResponse.body) as List;

        // OBTENEMOS IDs DE ALUMNOS CON PRÁCTICA
        final assignedStudentIds = <int>{};
        for (final p in practicesData) {
          final studentsList = p['students'] as List<dynamic>? ?? [];
          for (final s in studentsList) {
            assignedStudentIds.add((s['id'] as num).toInt());
          }
        }

        // MAPEO Y FILTRADO DE ALUMNOS (Ocultamos los asignados)
        final alumnosListaAll = studentsData.map((json) => SimpleStudent.fromJson(json)).toList();
        final alumnosLista = alumnosListaAll.where((a) => !assignedStudentIds.contains(a.id)).toList();

        final cursosSet = <String>{};
        for (final a in alumnosLista) {
          if (a.courseName.isNotEmpty) cursosSet.add(a.courseName);
        }

        final tutoresLista = traineesData.map((json) => SimpleTrainee.fromJson(json)).toList();

        setState(() {
          alumnos = alumnosLista;
          empresas = companiesData.map((json) => SimpleCompany.fromJson(json)).toList();
          tutores = tutoresLista;
          tutoresFiltrados = List.from(tutores);
          cursosAlumnosDisponibles = cursosSet.toList()..sort();
          filtroCursoAlumnos = null;
          cargandoDatos = false;
        });
      } else {
        setState(() => cargandoDatos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar alumnos/empresas/tutores'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() => cargandoDatos = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  List<SimpleStudent> get alumnosFiltrados {
    if (filtroCursoAlumnos == null || filtroCursoAlumnos!.isEmpty) return alumnos;
    return alumnos.where((a) => a.courseName == filtroCursoAlumnos).toList();
  }

  void actualizarTutoresFiltrados() {
    if (empresaSeleccionada == null) {
      tutoresFiltrados = List.from(tutores);
    } else {
      final companyId = empresaSeleccionada!.id;
      tutoresFiltrados = tutores.where((t) => t.companyId == companyId).toList();
    }
    if (!tutoresFiltrados.contains(tutorSeleccionado)) {
      tutorSeleccionado = null;
    }
  }

  String? validarTexto(String? value, String campo) {
    if (value == null || value.trim().isEmpty) return 'Introduce $campo';
    return null;
  }

  Future<void> seleccionarFechaInicio() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 2);
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicioSeleccionada ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('es', 'ES'),
    );
    if (seleccionada != null) {
      setState(() {
        fechaInicioSeleccionada = seleccionada;
        fechaInicioController.text = formatToUiDate(seleccionada);
      });
    }
  }

  Future<void> seleccionarFechaFin() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 3);
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaFinSeleccionada ?? fechaInicioSeleccionada ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('es', 'ES'),
    );
    if (seleccionada != null) {
      setState(() {
        fechaFinSeleccionada = seleccionada;
        fechaFinController.text = formatToUiDate(seleccionada);
      });
    }
  }

  Future<void> seleccionarHoraInicio() async {
    final TimeOfDay? seleccionada = await showTimePicker(
      context: context,
      initialTime: horaInicioSeleccionada ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (seleccionada != null) {
      setState(() {
        horaInicioSeleccionada = seleccionada;
        final hora = seleccionada.hour.toString().padLeft(2, '0');
        final minuto = seleccionada.minute.toString().padLeft(2, '0');
        horaInicioController.text = "$hora:$minuto";
      });
    }
  }

  Future<void> seleccionarHoraFin() async {
    final TimeOfDay? seleccionada = await showTimePicker(
      context: context,
      initialTime: horaFinSeleccionada ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (seleccionada != null) {
      setState(() {
        horaFinSeleccionada = seleccionada;
        final hora = seleccionada.hour.toString().padLeft(2, '0');
        final minuto = seleccionada.minute.toString().padLeft(2, '0');
        horaFinController.text = "$hora:$minuto";
      });
    }
  }

  Future<void> crearPractica() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los datos del formulario'), backgroundColor: accentColor),
      );
      return;
    }

    if (empresaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una empresa'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (tutorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un tutor'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (alumnosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un alumno'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final inicio = parseUiDate(fechaInicioController.text.trim());
    final fin = parseUiDate(fechaFinController.text.trim());

    if (inicio == null || fin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fechas inválidas, usa dd/mm/yyyy'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => creando = true);
    try {
      final url = Uri.parse('http://localhost:8080/api/practices');
      final totalHours = int.parse(horasTotalesController.text.trim());
      final dailyHours = int.parse(horasDiariasController.text.trim());

      final body = jsonEncode({
        "companyId": empresaSeleccionada!.id,
        "traineeId": tutorSeleccionado!.id,
        "studentIds": alumnosSeleccionados.toList(),
        "workplace": lugarTrabajoController.text.trim(),
        "startDate": formatToBackendDate(inicio),
        "endDate": formatToBackendDate(fin),
        "schedule": horarioController.text.trim(),
        "totalHours": totalHours,
        "dailyHours": dailyHours,
        "startTime": horaInicioController.text.trim(),
        "endTime": horaFinController.text.trim(),
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
          const SnackBar(content: Text('Práctica creada correctamente'), backgroundColor: accentColor),
        );
        _formKey.currentState!.reset();
        empresaSearchController.clear();
        lugarTrabajoController.clear();
        fechaInicioController.clear();
        fechaFinController.clear();
        horarioController.clear();
        horasTotalesController.clear();
        horasDiariasController.clear();

        // RESTAURAR VALORES POR DEFECTO
        horaInicioController.text = "09:00";
        horaFinController.text = "18:00";
        horaInicioSeleccionada = const TimeOfDay(hour: 9, minute: 0);
        horaFinSeleccionada = const TimeOfDay(hour: 18, minute: 0);

        alumnosSeleccionados.clear();
        empresaSeleccionada = null;
        tutorSeleccionado = null;
        fechaInicioSeleccionada = null;
        fechaFinSeleccionada = null;
        mostrandoSugerenciasEmpresa = false;

        setState(() {});

        // Recargar datos iniciales para que el alumno recién asignado desaparezca de la lista
        cargarDatosIniciales();

        widget.onPracticaCreada?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode} - ${response.body}'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear práctica: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => creando = false);
    }
  }

  Color surfaceColor(BuildContext context) => Theme.of(context).colorScheme.surface;
  Color borderThemeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF263041) : const Color(0xFFD7DEE8);
  Color mutedTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.68) : Colors.black.withOpacity(0.60);
  Color innerCardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111720) : const Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    if (cargandoDatos) {
      return const Center(child: CircularProgressIndicator());
    }

    final empresasFiltradas = empresas.where((e) {
      final query = empresaSearchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return e.legalName.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
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
                  'Crear práctica de alumno',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona uno o varios alumnos, una empresa y un tutor, e indica los datos de la práctica.',
                  style: TextStyle(color: mutedTextColor(context)),
                ),
                const SizedBox(height: 24),

                // Filtro alumnos
                Row(
                  children: [
                    const Text('Alumnos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (cursosAlumnosDisponibles.isNotEmpty)
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String>(
                          isDense: true,
                          value: filtroCursoAlumnos,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por curso',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todos los cursos'),
                            ),
                            ...cursosAlumnosDisponibles.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              filtroCursoAlumnos = value;
                            });
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: innerCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderThemeColor(context)),
                  ),
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: alumnosFiltrados.isEmpty
                      ? const Center(child: Text("No hay alumnos disponibles sin práctica."))
                      : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      itemCount: alumnosFiltrados.length,
                      itemBuilder: (context, index) {
                        final alumno = alumnosFiltrados[index];
                        final selected = alumnosSeleccionados.contains(alumno.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                alumnosSeleccionados.add(alumno.id);
                              } else {
                                alumnosSeleccionados.remove(alumno.id);
                              }
                            });
                          },
                          title: Text('${alumno.fullName} (${alumno.courseName})'),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Empresa
                const Text('Empresa'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: empresaSearchController,
                  decoration: const InputDecoration(
                    hintText: 'Empieza a escribir el nombre de la empresa...',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  onChanged: (value) {
                    setState(() {
                      mostrandoSugerenciasEmpresa = value.trim().isNotEmpty;
                    });
                  },
                  validator: (_) => empresaSeleccionada == null ? 'Selecciona una empresa' : null,
                ),
                if (mostrandoSugerenciasEmpresa)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: innerCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderThemeColor(context)),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: empresasFiltradas.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No hay empresas que coincidan'),
                    )
                        : ListView.builder(
                      itemCount: empresasFiltradas.length,
                      itemBuilder: (context, index) {
                        final e = empresasFiltradas[index];
                        return ListTile(
                          title: Text(e.legalName),
                          onTap: () {
                            setState(() {
                              empresaSeleccionada = e;
                              empresaSearchController.text = e.legalName;
                              mostrandoSugerenciasEmpresa = false;
                              actualizarTutoresFiltrados();
                              if (lugarTrabajoController.text.trim().isEmpty) {
                                lugarTrabajoController.text = e.fullAddress;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),

                // Tutor
                const Text('Tutor de empresa'),
                const SizedBox(height: 8),
                DropdownButtonFormField<SimpleTrainee>(
                  value: tutorSeleccionado,
                  items: tutoresFiltrados
                      .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.fullName),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      tutorSeleccionado = value;
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Selecciona un tutor',
                  ),
                  validator: (value) => value == null ? 'Selecciona un tutor' : null,
                ),
                const SizedBox(height: 24),

                // Datos de práctica
                const Text(
                  'Datos de la práctica',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text('Lugar de trabajo'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: lugarTrabajoController,
                  decoration: const InputDecoration(
                    hintText: 'Centro, sede, dirección...',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => validarTexto(value, 'el lugar de trabajo'),
                ),
                const SizedBox(height: 16),

                // Horas Totales y Diarias
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Horas totales'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: horasTotalesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Ej. 370',
                              prefixIcon: Icon(Icons.timer_outlined),
                            ),
                            validator: (value) => validarTexto(value, 'las horas totales'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Horas diarias'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: horasDiariasController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Ej. 5',
                              prefixIcon: Icon(Icons.timer),
                            ),
                            validator: (value) => validarTexto(value, 'las horas diarias'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fechas Inicio y Fin
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fecha de inicio'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: fechaInicioController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'dd/mm/yyyy',
                              prefixIcon: Icon(Icons.date_range_outlined),
                            ),
                            onTap: seleccionarFechaInicio,
                            validator: (value) => validarTexto(value, 'la fecha de inicio'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fecha de fin'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: fechaFinController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'dd/mm/yyyy',
                              prefixIcon: Icon(Icons.date_range_outlined),
                            ),
                            onTap: seleccionarFechaFin,
                            validator: (value) => validarTexto(value, 'la fecha de fin'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Horas Inicio y Fin
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hora de inicio'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: horaInicioController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'HH:mm',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            onTap: seleccionarHoraInicio,
                            validator: (value) => validarTexto(value, 'la hora de inicio'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hora de fin'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: horaFinController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'HH:mm',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            onTap: seleccionarHoraFin,
                            validator: (value) => validarTexto(value, 'la hora de fin'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Horario Descriptivo
                const Text('Horario (Descripción)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: horarioController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. L-V 9:00-14:00',
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  validator: (value) => validarTexto(value, 'el horario'),
                ),
                const SizedBox(height: 24),

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
                    onPressed: creando ? null : crearPractica,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      creando ? 'Creando...' : 'Crear práctica',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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