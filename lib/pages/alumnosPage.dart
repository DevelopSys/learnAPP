import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../model/course.dart';

const Color accentColor = Color(0xFF3ECF8E);

class StudentItem {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String dni;
  final String? address;
  final String? birthDate;
  final String? courseName;
  final int? courseId;

  // NUEVO: si el botón de anexo 6 depende de la práctica asociada
  final int? practiceId;

  StudentItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.dni,
    this.address,
    this.birthDate,
    this.courseName,
    this.courseId,
    this.practiceId,
  });

  factory StudentItem.fromJson(Map<String, dynamic> json) {
    final courseJson = json['course'] as Map<String, dynamic>?;
    final practiceJson = json['practice'] as Map<String, dynamic>?;

    return StudentItem(
      id: json['id'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      dni: json['dni'] ?? '',
      address: json['address'],
      birthDate: json['birthDate'],
      courseName: courseJson?['name'] ?? '',
      courseId: courseJson?['id'],
      practiceId: practiceJson?['id'],
    );
  }
}

class AlumnosPage extends StatefulWidget {
  final String jwt;

  const AlumnosPage({super.key, required this.jwt});

  @override
  State<AlumnosPage> createState() => _AlumnosPageState();
}

class _AlumnosPageState extends State<AlumnosPage> {
  final GlobalKey<ListadoAlumnosTabState> listadoKey =
  GlobalKey<ListadoAlumnosTabState>();

  void refrescarListado() {
    listadoKey.currentState?.cargarAlumnos();
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
                  icon: Icon(Icons.person_add_alt_1),
                  text: 'Agregar',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListadoAlumnosTab(
                  key: listadoKey,
                  jwt: widget.jwt,
                ),
                AgregarAlumnoTab(
                  jwt: widget.jwt,
                  onAlumnoGuardado: refrescarListado,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListadoAlumnosTab extends StatefulWidget {
  final String jwt;

  const ListadoAlumnosTab({super.key, required this.jwt});

  @override
  State<ListadoAlumnosTab> createState() => ListadoAlumnosTabState();
}

class ListadoAlumnosTabState extends State<ListadoAlumnosTab> {
  List<StudentItem> alumnos = [];
  List<Course> cursos = [];
  int? cursoFiltroId;

  final TextEditingController buscarApellidoController =
  TextEditingController();
  String textoBusquedaApellido = '';

  bool cargandoAlumnos = true;
  bool cargandoCursos = true;
  bool procesando = false;

  @override
  void initState() {
    super.initState();
    cargarInicial();
  }

  @override
  void dispose() {
    buscarApellidoController.dispose();
    super.dispose();
  }

  Future<void> cargarInicial() async {
    await Future.wait([
      cargarAlumnos(),
      cargarCursos(),
    ]);
  }

  Future<void> cargarAlumnos() async {
    setState(() {
      cargandoAlumnos = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/students');

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
          alumnos = data.map((json) => StudentItem.fromJson(json)).toList();
          cargandoAlumnos = false;
        });
      } else {
        setState(() {
          cargandoAlumnos = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar alumnos: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() {
        cargandoAlumnos = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al cargar alumnos: $e'),
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

  List<StudentItem> get alumnosFiltrados {
    return alumnos.where((alumno) {
      final coincideCurso =
          cursoFiltroId == null || alumno.courseId == cursoFiltroId;

      final apellidoCompleto = alumno.lastName.toLowerCase();
      final textoBusqueda = textoBusquedaApellido.trim().toLowerCase();

      final coincideApellido =
          textoBusqueda.isEmpty || apellidoCompleto.contains(textoBusqueda);

      return coincideCurso && coincideApellido;
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

  Future<void> borrarAlumno(int id) async {
    final confirmado = await confirmarAccion(
      titulo: 'Eliminar alumno',
      mensaje: '¿Seguro que quieres eliminar este alumno?',
    );

    if (!confirmado) return;

    setState(() {
      procesando = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/students/$id');

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
            content: Text('Alumno eliminado correctamente'),
            backgroundColor: accentColor,
          ),
        );
        await cargarAlumnos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar alumno: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al eliminar alumno: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        procesando = false;
      });
    }
  }

  Future<void> borrarTodosLosAlumnos() async {
    if (alumnos.isEmpty) return;

    final confirmado = await confirmarAccion(
      titulo: 'Vaciar tabla',
      mensaje:
      '¿Seguro que quieres eliminar todos los alumnos? Esta acción no se puede deshacer.',
    );

    if (!confirmado) return;

    setState(() {
      procesando = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/students');

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
            content: Text('Todos los alumnos han sido eliminados'),
            backgroundColor: accentColor,
          ),
        );

        setState(() {
          alumnos = [];
          cursoFiltroId = null;
          textoBusquedaApellido = '';
          buscarApellidoController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al borrar todos: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al borrar alumnos: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        procesando = false;
      });
    }
  }

  Future<void> editarAlumno(StudentItem alumno) async {
    final nombreController = TextEditingController(text: alumno.firstName);
    final apellidoController = TextEditingController(text: alumno.lastName);
    final correoController = TextEditingController(text: alumno.email);
    final dniController = TextEditingController(text: alumno.dni);
    final direccionController =
    TextEditingController(text: alumno.address ?? '');

    int? cursoEditadoId = alumno.courseId;
    final formKey = GlobalKey<FormState>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar alumno'),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el nombre'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: apellidoController,
                          decoration: const InputDecoration(
                            labelText: 'Apellido',
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el apellido'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: correoController,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Introduce el correo';
                            }
                            final emailRegex =
                            RegExp(r'^[^@]+@[^@]+\.[^@]+');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Correo no válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dniController,
                          decoration: const InputDecoration(
                            labelText: 'DNI',
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el DNI'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: direccionController,
                          decoration: const InputDecoration(
                            labelText: 'Dirección',
                          ),
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
      nombreController.dispose();
      apellidoController.dispose();
      correoController.dispose();
      dniController.dispose();
      direccionController.dispose();
      return;
    }

    setState(() {
      procesando = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/students/${alumno.id}');

      final body = jsonEncode({
        'firstName': nombreController.text.trim(),
        'lastName': apellidoController.text.trim(),
        'email': correoController.text.trim(),
        'dni': dniController.text.trim(),
        'birthDate': alumno.birthDate,
        'address': direccionController.text.trim(),
        'course': {
          'id': cursoEditadoId,
        },
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
            content: Text('Alumno actualizado correctamente'),
            backgroundColor: accentColor,
          ),
        );
        await cargarAlumnos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar alumno: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al actualizar alumno: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      nombreController.dispose();
      apellidoController.dispose();
      correoController.dispose();
      dniController.dispose();
      direccionController.dispose();

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
    if (cargandoAlumnos || cargandoCursos) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1300),
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
                'Listado de alumnos',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Consulta, filtra, busca, edita, elimina y descarga el anexo 6.',
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

                  final buscadorApellido = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Buscar por apellido'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: buscarApellidoController,
                        decoration: InputDecoration(
                          hintText: 'Escribe un apellido',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: textoBusquedaApellido.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              buscarApellidoController.clear();
                              setState(() {
                                textoBusquedaApellido = '';
                              });
                            },
                          )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            textoBusquedaApellido = value;
                          });
                        },
                      ),
                    ],
                  );

                  final botonBorrarTodos = SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: procesando ? null : borrarTodosLosAlumnos,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text(
                        'Borrar todos',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  );

                  if (esAncho) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: filtroCurso),
                        const SizedBox(width: 16),
                        Expanded(child: buscadorApellido),
                        const SizedBox(width: 16),
                        botonBorrarTodos,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      filtroCurso,
                      const SizedBox(height: 16),
                      buscadorApellido,
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: botonBorrarTodos,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (alumnosFiltrados.isEmpty)
                Text(
                  'No hay alumnos que coincidan con los filtros aplicados.',
                  style: TextStyle(color: mutedTextColor(context)),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Apellidos')),
                      DataColumn(label: Text('Correo')),
                      DataColumn(label: Text('DNI')),
                      DataColumn(label: Text('Curso')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: alumnosFiltrados.map((alumno) {
                      return DataRow(
                        cells: [
                          DataCell(Text(alumno.firstName)),
                          DataCell(Text(alumno.lastName)),
                          DataCell(Text(alumno.email)),
                          DataCell(Text(alumno.dni)),
                          DataCell(Text(alumno.courseName ?? 'Sin curso')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar alumno',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: procesando
                                      ? null
                                      : () => editarAlumno(alumno),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar alumno',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: procesando
                                      ? null
                                      : () => borrarAlumno(alumno.id),
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

class AgregarAlumnoTab extends StatefulWidget {
  final String jwt;
  final VoidCallback? onAlumnoGuardado;

  const AgregarAlumnoTab({
    super.key,
    required this.jwt,
    this.onAlumnoGuardado,
  });

  @override
  State<AgregarAlumnoTab> createState() => _AgregarAlumnoTabState();
}

class _AgregarAlumnoTabState extends State<AgregarAlumnoTab> {
  final _formKey = GlobalKey<FormState>();

  final nombreController = TextEditingController();
  final apellidoController = TextEditingController();
  final correoController = TextEditingController();
  final dniController = TextEditingController();
  final fechaController = TextEditingController();
  final direccionController = TextEditingController();

  Course? cursoSeleccionado;
  List<Course> ciclos = [];
  DateTime? fechaNacimiento;

  bool procesandoCsv = false;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  @override
  void dispose() {
    nombreController.dispose();
    apellidoController.dispose();
    correoController.dispose();
    dniController.dispose();
    fechaController.dispose();
    direccionController.dispose();
    super.dispose();
  }

  Future<void> cargarDatos() async {
    final url = Uri.parse('http://localhost:8080/api/courses');

    final courseResponse = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.jwt}',
      },
    );

    if (courseResponse.statusCode == 200) {
      final List<dynamic> data = jsonDecode(courseResponse.body);

      setState(() {
        ciclos = data.map((json) => Course.fromJson(json)).toList();
      });
    } else {
      debugPrint('Error cargando cursos: ${courseResponse.body}');
    }
  }

  Future<void> seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2010),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        fechaNacimiento = picked;
        fechaController.text =
        '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  Future<void> guardarAlumno() async {
    if (_formKey.currentState!.validate()) {
      final url = Uri.parse('http://localhost:8080/api/students');

      final body = jsonEncode({
        'firstName': nombreController.text.trim(),
        'lastName': apellidoController.text.trim(),
        'email': correoController.text.trim(),
        'dni': dniController.text.trim(),
        'birthDate': fechaNacimiento?.toIso8601String().split('T').first,
        'address': direccionController.text.trim(),
        'course': {
          'id': cursoSeleccionado?.id,
        },
      });

      final studentsResponse = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwt}',
        },
        body: body,
      );

      if (studentsResponse.statusCode == 200 ||
          studentsResponse.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alumno agregado correctamente'),
            backgroundColor: accentColor,
          ),
        );

        nombreController.clear();
        apellidoController.clear();
        correoController.clear();
        dniController.clear();
        fechaController.clear();
        direccionController.clear();

        setState(() {
          cursoSeleccionado = null;
          fechaNacimiento = null;
        });

        widget.onAlumnoGuardado?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${studentsResponse.body}'),
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

  Future<void> subirCsvAlumnos() async {
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

      final uri = Uri.parse('http://localhost:8080/api/students/upload');

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
          const SnackBar(
            content: Text('CSV procesado correctamente'),
            backgroundColor: accentColor,
          ),
        );
        widget.onAlumnoGuardado?.call();
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
      final url = Uri.parse('http://localhost:8080/api/students/template');

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
        final blob =
        web.Blob([data].toJS, web.BlobPropertyBag(type: 'text/csv'));
        final downloadUrl = web.URL.createObjectURL(blob);

        final anchor = web.HTMLAnchorElement()
          ..href = downloadUrl
          ..download = 'plantilla_alumnos.csv'
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
                  'Alta de alumno',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rellena los datos del alumno o utiliza un fichero CSV.',
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
                        onPressed: procesandoCsv ? null : subirCsvAlumnos,
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
                const Text('Ciclo formativo'),
                const SizedBox(height: 8),
                DropdownButtonFormField<Course>(
                  value: cursoSeleccionado,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  decoration: const InputDecoration(
                    hintText: 'Selecciona un curso',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: ciclos.map((curso) {
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
                const Text('Nombre'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    hintText: 'Introduce el nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Introduce el nombre'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text('Apellido'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: apellidoController,
                  decoration: const InputDecoration(
                    hintText: 'Introduce el apellido',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Introduce el apellido'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text('Correo'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'correo@ejemplo.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce el correo';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Correo no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('DNI'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: dniController,
                  decoration: const InputDecoration(
                    hintText: '12345678A',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce el DNI';
                    }
                    if (value.trim().length < 9) {
                      return 'DNI no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Dirección'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: direccionController,
                  decoration: const InputDecoration(
                    hintText: 'Introduce una dirección',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Introduce una dirección'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text('Fecha de nacimiento'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: fechaController,
                  readOnly: true,
                  onTap: seleccionarFecha,
                  decoration: const InputDecoration(
                    hintText: 'Selecciona una fecha',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Selecciona la fecha de nacimiento'
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
                    onPressed: guardarAlumno,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text(
                      'Agregar alumno',
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