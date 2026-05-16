import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const Color accentColor = Color(0xFF3ECF8E);

class InfoCourseItem {
  final int? id;
  final String directorName;
  final String directorLastName;
  final String directorNif;
  final String schoolNumber;
  final String schoolName;
  final String schoolEmail;
  final String schoolPhone;
  final String schoolAddress;
  final String schoolPostalCode;
  final String schoolLocal;
  final String schoolState;
  final String schoolCity;
  final String schoolYear;

  InfoCourseItem({
    this.id,
    required this.directorName,
    required this.directorLastName,
    required this.directorNif,
    required this.schoolNumber,
    required this.schoolName,
    required this.schoolEmail,
    required this.schoolPhone,
    required this.schoolAddress,
    required this.schoolPostalCode,
    required this.schoolLocal,
    required this.schoolState,
    required this.schoolCity,
    required this.schoolYear,
  });

  factory InfoCourseItem.fromJson(Map<String, dynamic> json) {
    return InfoCourseItem(
      id: json['id'],
      directorName: (json['directorName'] ?? '').toString(),
      directorLastName: (json['directorLastName'] ?? '').toString(),
      directorNif: (json['directorNif'] ?? '').toString(),
      schoolNumber: (json['schoolNumber'] ?? '').toString(),
      schoolName: (json['schoolName'] ?? '').toString(),
      schoolEmail: (json['schoolEmail'] ?? '').toString(),
      schoolPhone: (json['schoolPhone'] ?? '').toString(),
      schoolAddress: (json['schoolAddress'] ?? '').toString(),
      schoolPostalCode: (json['schoolPostalCode'] ?? '').toString(),
      schoolLocal: (json['schoolLocal'] ?? '').toString(),
      schoolState: (json['schoolState'] ?? '').toString(),
      schoolCity: (json['schoolCity'] ?? '').toString(),
      schoolYear: (json['schoolYear'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'directorName': directorName,
      'directorLastName': directorLastName,
      'directorNif': directorNif,
      'schoolNumber': schoolNumber,
      'schoolName': schoolName,
      'schoolEmail': schoolEmail,
      'schoolPhone': schoolPhone,
      'schoolAddress': schoolAddress,
      'schoolPostalCode': schoolPostalCode,
      'schoolLocal': schoolLocal,
      'schoolState': schoolState,
      'schoolCity': schoolCity,
      'schoolYear': schoolYear,
    };
  }
}

class InfoCoursePage extends StatefulWidget {
  final String jwt;

  const InfoCoursePage({super.key, required this.jwt});

  @override
  State<InfoCoursePage> createState() => _InfoCoursePageState();
}

class _InfoCoursePageState extends State<InfoCoursePage> {
  final _formKey = GlobalKey<FormState>();

  final directorNameController = TextEditingController();
  final directorLastNameController = TextEditingController();
  final directorNifController = TextEditingController();
  final schoolNumberController = TextEditingController();
  final schoolNameController = TextEditingController();
  final schoolEmailController = TextEditingController();
  final schoolPhoneController = TextEditingController();
  final schoolAddressController = TextEditingController();
  final schoolPostalCodeController = TextEditingController();
  final schoolLocalController = TextEditingController();
  final schoolStateController = TextEditingController();
  final schoolCityController = TextEditingController();
  final schoolYearController = TextEditingController();

  InfoCourseItem? currentInfo;

  bool cargando = true;
  bool guardando = false;
  bool eliminando = false;
  bool recargando = false;

  @override
  void initState() {
    super.initState();
    cargarInfoCourse();
  }

  @override
  void dispose() {
    directorNameController.dispose();
    directorLastNameController.dispose();
    directorNifController.dispose();
    schoolNumberController.dispose();
    schoolNameController.dispose();
    schoolEmailController.dispose();
    schoolPhoneController.dispose();
    schoolAddressController.dispose();
    schoolPostalCodeController.dispose();
    schoolLocalController.dispose();
    schoolStateController.dispose();
    schoolCityController.dispose();
    schoolYearController.dispose();
    super.dispose();
  }

  Future<void> cargarInfoCourse({bool silent = false}) async {
    if (!silent) {
      setState(() {
        cargando = true;
      });
    } else {
      setState(() {
        recargando = true;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/info-courses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        if (data.isEmpty) {
          currentInfo = null;
          limpiarFormulario();
        } else {
          final info = InfoCourseItem.fromJson(data.first);
          currentInfo = info;
          rellenarFormulario(info);
        }

        if (mounted) {
          setState(() {});
        }
      } else {
        mostrarError('Error al cargar la configuración: ${response.statusCode}');
      }
    } catch (e) {
      mostrarError('Error de conexión al cargar la configuración: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        cargando = false;
        recargando = false;
      });
    }
  }

  void rellenarFormulario(InfoCourseItem info) {
    directorNameController.text = info.directorName;
    directorLastNameController.text = info.directorLastName;
    directorNifController.text = info.directorNif;
    schoolNumberController.text = info.schoolNumber;
    schoolNameController.text = info.schoolName;
    schoolEmailController.text = info.schoolEmail;
    schoolPhoneController.text = info.schoolPhone;
    schoolAddressController.text = info.schoolAddress;
    schoolPostalCodeController.text = info.schoolPostalCode;
    schoolLocalController.text = info.schoolLocal;
    schoolStateController.text = info.schoolState;
    schoolCityController.text = info.schoolCity;
    schoolYearController.text = info.schoolYear;
  }

  void limpiarFormulario() {
    directorNameController.clear();
    directorLastNameController.clear();
    directorNifController.clear();
    schoolNumberController.clear();
    schoolNameController.clear();
    schoolEmailController.clear();
    schoolPhoneController.clear();
    schoolAddressController.clear();
    schoolPostalCodeController.clear();
    schoolLocalController.clear();
    schoolStateController.clear();
    schoolCityController.clear();
    schoolYearController.clear();
  }

  Future<void> guardarInfoCourse() async {
    if (!_formKey.currentState!.validate()) {
      mostrarError('Comprueba los datos del formulario');
      return;
    }

    setState(() {
      guardando = true;
    });

    final payload = jsonEncode({
      'directorName': directorNameController.text.trim(),
      'directorLastName': directorLastNameController.text.trim(),
      'directorNif': directorNifController.text.trim(),
      'schoolNumber': schoolNumberController.text.trim(),
      'schoolName': schoolNameController.text.trim(),
      'schoolEmail': schoolEmailController.text.trim(),
      'schoolPhone': schoolPhoneController.text.trim(),
      'schoolAddress': schoolAddressController.text.trim(),
      'schoolPostalCode': schoolPostalCodeController.text.trim(),
      'schoolLocal': schoolLocalController.text.trim(),
      'schoolState': schoolStateController.text.trim(),
      'schoolCity': schoolCityController.text.trim(),
      'schoolYear': schoolYearController.text.trim(),
    });

    try {
      late http.Response response;

      if (currentInfo?.id == null) {
        response = await http.post(
          Uri.parse('http://localhost:8080/api/info-courses'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer ${widget.jwt}',
          },
          body: payload,
        );
      } else {
        response = await http.put(
          Uri.parse('http://localhost:8080/api/info-courses/${currentInfo!.id}'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer ${widget.jwt}',
          },
          body: payload,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        mostrarOk(
          currentInfo?.id == null
              ? 'Configuración guardada correctamente'
              : 'Configuración actualizada correctamente',
        );
        await cargarInfoCourse(silent: true);
      } else {
        mostrarError('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      mostrarError('Error de conexión al guardar: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        guardando = false;
      });
    }
  }

  Future<void> eliminarInfoCourse() async {
    if (currentInfo?.id == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar configuración'),
          content: const Text(
            '¿Seguro que quieres eliminar la información actual del centro y del curso? Esta acción no se puede deshacer.',
          ),
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
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) return;

    setState(() {
      eliminando = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('http://localhost:8080/api/info-courses/${currentInfo!.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        currentInfo = null;
        limpiarFormulario();
        if (mounted) {
          setState(() {});
        }
        mostrarOk('Configuración eliminada correctamente');
      } else {
        mostrarError('Error al eliminar: ${response.statusCode}');
      }
    } catch (e) {
      mostrarError('Error de conexión al eliminar: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        eliminando = false;
      });
    }
  }

  void cargarEjemplo() {
    directorNameController.text = 'María';
    directorLastNameController.text = 'Gómez Martín';
    directorNifController.text = '12345678A';
    schoolNumberController.text = '28039845';
    schoolNameController.text = 'IES Example Center';
    schoolEmailController.text = 'direccion@iesexample.es';
    schoolPhoneController.text = '916000000';
    schoolAddressController.text = 'Calle Ejemplo 12';
    schoolPostalCodeController.text = '28901';
    schoolLocalController.text = 'Getafe';
    schoolStateController.text = 'Madrid';
    schoolCityController.text = 'Getafe';
    schoolYearController.text = '2025/2026';

    setState(() {});
  }

  void mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void mostrarOk(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: accentColor,
      ),
    );
  }

  String? validarTexto(String? value, String campo) {
    if (value == null || value.trim().isEmpty) {
      return 'Introduce $campo';
    }
    return null;
  }

  String? validarEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Introduce el correo electrónico';
    }

    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!regex.hasMatch(value.trim())) {
      return 'Correo no válido';
    }
    return null;
  }

  String? validarTelefono(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Introduce el teléfono';
    }

    if (value.trim().length < 9) {
      return 'Teléfono no válido';
    }
    return null;
  }

  String? validarCursoEscolar(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Introduce el curso académico';
    }

    final regex = RegExp(r'^\d{4}\/\d{4}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Formato esperado: 2025/2026';
    }

    return null;
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

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget sectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: innerCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderThemeColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: accentColor),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: mutedTextColor(context)),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget buildResumenSuperior(BuildContext context) {
    final tieneDatos = currentInfo != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: innerCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderThemeColor(context)),
      ),
      child: Wrap(
        runSpacing: 12,
        spacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estado de la configuración',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tieneDatos
                    ? 'Hay una configuración guardada y lista para editar.'
                    : 'Todavía no hay ninguna configuración creada.',
                style: TextStyle(color: mutedTextColor(context)),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderThemeColor(context)),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: recargando || guardando || eliminando
                    ? null
                    : () => cargarInfoCourse(silent: true),
                icon: recargando
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.refresh),
                label: const Text('Recargar'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderThemeColor(context)),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: guardando || eliminando ? null : cargarEjemplo,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Rellenar ejemplo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: innerCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderThemeColor(context)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.school_outlined,
            size: 46,
            color: accentColor,
          ),
          const SizedBox(height: 14),
          const Text(
            'No hay configuración creada',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rellena el formulario para guardar los datos del centro, la dirección y el curso académico actual.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedTextColor(context)),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
            ),
            onPressed: cargarEjemplo,
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Cargar ejemplo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Información del centro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 950),
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
                    'Configuración general',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aquí puedes definir la información global del centro y del curso académico vigente que se utilizará en los documentos.',
                    style: TextStyle(color: mutedTextColor(context)),
                  ),
                  const SizedBox(height: 24),

                  buildResumenSuperior(context),
                  const SizedBox(height: 20),

                  if (currentInfo == null) ...[
                    buildEmptyState(context),
                    const SizedBox(height: 20),
                  ],

                  sectionCard(
                    context: context,
                    title: 'Equipo directivo',
                    subtitle:
                    'Datos de la dirección del centro para usar en la documentación.',
                    icon: Icons.badge_outlined,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 700;

                          final nombre = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nombre del director/a'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: directorNameController,
                                decoration: inputDecoration(
                                  hint: 'Introduce el nombre',
                                  icon: Icons.person_outline,
                                ),
                                validator: (value) =>
                                    validarTexto(value, 'el nombre del director/a'),
                              ),
                            ],
                          );

                          final apellidos = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Apellidos del director/a'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: directorLastNameController,
                                decoration: inputDecoration(
                                  hint: 'Introduce los apellidos',
                                  icon: Icons.badge_outlined,
                                ),
                                validator: (value) => validarTexto(
                                  value,
                                  'los apellidos del director/a',
                                ),
                              ),
                            ],
                          );

                          final nif = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NIF del director/a'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: directorNifController,
                                decoration: inputDecoration(
                                  hint: '12345678A',
                                  icon: Icons.credit_card_outlined,
                                ),
                                validator: (value) =>
                                    validarTexto(value, 'el NIF del director/a'),
                              ),
                            ],
                          );

                          if (isWide) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: nombre),
                                    const SizedBox(width: 16),
                                    Expanded(child: apellidos),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: nif),
                                    const SizedBox(width: 16),
                                    const Expanded(child: SizedBox()), // Para que no ocupe todo el ancho
                                  ],
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              nombre,
                              const SizedBox(height: 16),
                              apellidos,
                              const SizedBox(height: 16),
                              nif,
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  sectionCard(
                    context: context,
                    title: 'Datos del centro',
                    subtitle:
                    'Información identificativa y de contacto del centro educativo.',
                    icon: Icons.school_outlined,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 700;

                          final codigoCentro = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Código del centro'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: schoolNumberController,
                                decoration: inputDecoration(
                                  hint: 'Introduce el código',
                                  icon: Icons.numbers_outlined,
                                ),
                                validator: (value) =>
                                    validarTexto(value, 'el código del centro'),
                              ),
                            ],
                          );

                          final nombreCentro = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nombre del centro'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: schoolNameController,
                                decoration: inputDecoration(
                                  hint: 'Introduce el nombre',
                                  icon: Icons.apartment_outlined,
                                ),
                                validator: (value) =>
                                    validarTexto(value, 'el nombre del centro'),
                              ),
                            ],
                          );

                          final email = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Correo electrónico'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: schoolEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: inputDecoration(
                                  hint: 'centro@dominio.com',
                                  icon: Icons.mail_outline,
                                ),
                                validator: validarEmail,
                              ),
                            ],
                          );

                          final telefono = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Teléfono'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: schoolPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: inputDecoration(
                                  hint: '916000000',
                                  icon: Icons.phone_outlined,
                                ),
                                validator: validarTelefono,
                              ),
                            ],
                          );

                          if (isWide) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: codigoCentro),
                                    const SizedBox(width: 16),
                                    Expanded(flex: 2, child: nombreCentro),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(flex: 2, child: email),
                                    const SizedBox(width: 16),
                                    Expanded(child: telefono),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              codigoCentro,
                              const SizedBox(height: 16),
                              nombreCentro,
                              const SizedBox(height: 16),
                              email,
                              const SizedBox(height: 16),
                              telefono,
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      const Text('Dirección'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: schoolAddressController,
                        decoration: inputDecoration(
                          hint: 'Calle, número, etc.',
                          icon: Icons.location_on_outlined,
                        ),
                        validator: (value) =>
                            validarTexto(value, 'la dirección'),
                      ),

                      const SizedBox(height: 16),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 700;

                          final codigoPostal = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Código Postal'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: schoolPostalCodeController,
                                keyboardType: TextInputType.number,
                                decoration: inputDecoration(
                                  hint: '28001',
                                  icon: Icons.local_post_office_outlined,
                                ),
                                validator: (value) =>
                                    validarTexto(value, 'el código postal'),
                              ),
                            ],
                          );

                          final provincia = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Provincia'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: schoolStateController,
                                decoration: inputDecoration(
                                  hint: 'Madrid',
                                  icon: Icons.map_outlined,
                                ),
                                validator: (value) =>
                                    validarTexto(value, 'la provincia'),
                              ),
                            ],
                          );

                          final ciudad = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ciudad'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: schoolCityController,
                                decoration: inputDecoration(
                                  hint: 'Madrid',
                                  icon: Icons.location_city_outlined,
                                ),
                                validator: (value) =>
                                    validarTexto(value, 'la ciudad'),
                              ),
                            ],
                          );

                          final localidad = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Localidad'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: schoolLocalController,
                                decoration: inputDecoration(
                                  hint: 'Getafe',
                                  icon: Icons.holiday_village_outlined,
                                ),
                                validator: (value) =>
                                    validarTexto(value, 'la localidad'),
                              ),
                            ],
                          );

                          if (isWide) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: codigoPostal),
                                    const SizedBox(width: 16),
                                    Expanded(child: provincia),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: ciudad),
                                    const SizedBox(width: 16),
                                    Expanded(child: localidad),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              codigoPostal,
                              const SizedBox(height: 16),
                              provincia,
                              const SizedBox(height: 16),
                              ciudad,
                              const SizedBox(height: 16),
                              localidad,
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  sectionCard(
                    context: context,
                    title: 'Curso académico',
                    subtitle:
                    'Define el curso escolar activo que se utilizará en la documentación.',
                    icon: Icons.calendar_month_outlined,
                    children: [
                      const Text('Curso académico'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: schoolYearController,
                        decoration: inputDecoration(
                          hint: '2025/2026',
                          icon: Icons.date_range_outlined,
                        ),
                        validator: validarCursoEscolar,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 760;

                      final botonEliminar = OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onPressed: currentInfo == null || guardando || eliminando
                            ? null
                            : eliminarInfoCourse,
                        icon: eliminando
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.delete_outline),
                        label: const Text('Eliminar configuración'),
                      );

                      final botonGuardar = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: guardando || eliminando
                            ? null
                            : guardarInfoCourse,
                        icon: guardando
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          currentInfo == null
                              ? 'Guardar configuración'
                              : 'Actualizar configuración',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            botonEliminar,
                            const Spacer(),
                            botonGuardar,
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          botonEliminar,
                          const SizedBox(height: 12),
                          botonGuardar,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}