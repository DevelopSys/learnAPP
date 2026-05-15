import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const Color accentColor = Color(0xFF3ECF8E);

class CompanyItem {
  final int id;
  final String legalName;
  final String nif;

  CompanyItem({
    required this.id,
    required this.legalName,
    required this.nif,
  });

  factory CompanyItem.fromJson(Map<String, dynamic> json) {
    return CompanyItem(
      id: json['id'],
      legalName: json['legalName'] ?? '',
      nif: json['nif'] ?? '',
    );
  }

  @override
  String toString() => '$legalName ($nif)';
}

class TraineeItem {
  final int id;
  final String firstName;
  final String lastName;
  final String dni;
  final String email;
  final int? companyId;
  final String companyName;

  TraineeItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dni,
    required this.email,
    required this.companyId,
    required this.companyName,
  });

  factory TraineeItem.fromJson(Map<String, dynamic> json) {
    final companyJson = json['company'] as Map<String, dynamic>?;

    return TraineeItem(
      id: json['id'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      dni: json['dni'] ?? '',
      email: json['email'] ?? '',
      companyId: companyJson?['id'],
      companyName: companyJson?['legalName'] ?? '',
    );
  }
}

class TutoresPage extends StatefulWidget {
  final String jwt;

  const TutoresPage({super.key, required this.jwt});

  @override
  State<TutoresPage> createState() => _TutoresPageState();
}

class _TutoresPageState extends State<TutoresPage> {
  final GlobalKey<ListadoTutoresTabState> listadoKey =
  GlobalKey<ListadoTutoresTabState>();

  void refrescarListado() {
    listadoKey.currentState?.cargarTutores();
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
                ListadoTutoresTab(
                  key: listadoKey,
                  jwt: widget.jwt,
                ),
                AgregarTutorTab(
                  jwt: widget.jwt,
                  onTutorGuardado: refrescarListado,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListadoTutoresTab extends StatefulWidget {
  final String jwt;

  const ListadoTutoresTab({super.key, required this.jwt});

  @override
  State<ListadoTutoresTab> createState() => ListadoTutoresTabState();
}

class ListadoTutoresTabState extends State<ListadoTutoresTab> {
  List<TraineeItem> tutores = [];
  List<CompanyItem> empresas = [];

  final TextEditingController buscarApellidoController =
  TextEditingController();
  String textoBusquedaApellido = '';

  bool cargandoTutores = true;
  bool cargandoEmpresas = true;
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
      cargarTutores(),
      cargarEmpresas(),
    ]);
  }

  Future<void> cargarTutores() async {
    setState(() {
      cargandoTutores = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/trainees');

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
          tutores = data.map((json) => TraineeItem.fromJson(json)).toList();
          cargandoTutores = false;
        });
      } else {
        setState(() {
          cargandoTutores = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar tutores: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() {
        cargandoTutores = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> cargarEmpresas() async {
    setState(() {
      cargandoEmpresas = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/companies');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          empresas = data.map((item) => CompanyItem.fromJson(item)).toList();
          cargandoEmpresas = false;
        });
      } else {
        setState(() {
          cargandoEmpresas = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar empresas: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() {
        cargandoEmpresas = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al cargar empresas: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<TraineeItem> get tutoresFiltrados {
    final texto = textoBusquedaApellido.trim().toLowerCase();

    return tutores.where((tutor) {
      final apellido = tutor.lastName.toLowerCase();
      return texto.isEmpty || apellido.contains(texto);
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

  Future<void> borrarTutor(int id) async {
    final confirmado = await confirmarAccion(
      titulo: 'Eliminar tutor',
      mensaje: '¿Seguro que quieres eliminar este tutor?',
    );

    if (!confirmado) return;

    setState(() {
      procesando = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/trainees/$id');

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
            content: Text('Tutor eliminado correctamente'),
            backgroundColor: accentColor,
          ),
        );
        await cargarTutores();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar tutor: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al eliminar tutor: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        procesando = false;
      });
    }
  }

  Future<void> editarTutor(TraineeItem tutor) async {
    final nombreController = TextEditingController(text: tutor.firstName);
    final apellidoController = TextEditingController(text: tutor.lastName);
    final dniController = TextEditingController(text: tutor.dni);
    final emailController = TextEditingController(text: tutor.email);

    // Autocomplete para empresa en edición
    final empresaSearchController =
    TextEditingController(text: tutor.companyName);
    bool mostrandoSugerenciasEmpresa = false;

    CompanyItem? empresaSeleccionada = tutor.companyId == null
        ? null
        : empresas.firstWhere(
          (e) => e.id == tutor.companyId,
      orElse: () => empresas.isNotEmpty
          ? empresas.first
          : CompanyItem(id: 0, legalName: '', nif: ''),
    );
    if (empresaSeleccionada?.id == 0) {
      empresaSeleccionada = null;
    }

    final formKey = GlobalKey<FormState>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final empresasFiltradas = empresas.where((e) {
              final query =
              empresaSearchController.text.trim().toLowerCase();
              if (query.isEmpty) return true;
              return e.legalName.toLowerCase().contains(query) ||
                  e.nif.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('Editar tutor'),
              content: SizedBox(
                width: 550,
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
                            prefixIcon: Icon(Icons.person_outline),
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
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el apellido'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dniController,
                          decoration: const InputDecoration(
                            labelText: 'DNI',
                            prefixIcon: Icon(Icons.credit_card_outlined),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el DNI'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Introduce el email';
                            }

                            final regex =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                            if (!regex.hasMatch(value.trim())) {
                              return 'Introduce un email válido';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Empresa asociada (autocomplete)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Empresa'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: empresaSearchController,
                          decoration: const InputDecoration(
                            hintText: 'Empieza a escribir el nombre o NIF',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                          onChanged: (value) {
                            setStateDialog(() {
                              mostrandoSugerenciasEmpresa =
                                  value.trim().isNotEmpty;
                            });
                          },
                          validator: (_) => empresaSeleccionada == null
                              ? 'Selecciona una empresa'
                              : null,
                        ),
                        if (mostrandoSugerenciasEmpresa)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                  Brightness.dark
                                  ? const Color(0xFF111720)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                    Brightness.dark
                                    ? const Color(0xFF263041)
                                    : const Color(0xFFD7DEE8),
                              ),
                            ),
                            constraints:
                            const BoxConstraints(maxHeight: 200),
                            child: empresasFiltradas.isEmpty
                                ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child:
                              Text('No hay empresas que coincidan'),
                            )
                                : ListView.builder(
                              itemCount: empresasFiltradas.length,
                              itemBuilder: (context, index) {
                                final e = empresasFiltradas[index];
                                return ListTile(
                                  title: Text(
                                      '${e.legalName} (${e.nif})'),
                                  onTap: () {
                                    setStateDialog(() {
                                      empresaSeleccionada = e;
                                      empresaSearchController.text =
                                      '${e.legalName} (${e.nif})';
                                      mostrandoSugerenciasEmpresa =
                                      false;
                                    });
                                  },
                                );
                              },
                            ),
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
      dniController.dispose();
      emailController.dispose();
      empresaSearchController.dispose();
      return;
    }

    setState(() {
      procesando = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/trainees/${tutor.id}');

      final body = jsonEncode({
        'firstName': nombreController.text.trim(),
        'lastName': apellidoController.text.trim(),
        'dni': dniController.text.trim(),
        'email': emailController.text.trim(),
        'company': {
          'id': empresaSeleccionada!.id,
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
            content: Text('Tutor actualizado correctamente'),
            backgroundColor: accentColor,
          ),
        );
        await cargarTutores();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar tutor: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al actualizar tutor: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      nombreController.dispose();
      apellidoController.dispose();
      dniController.dispose();
      emailController.dispose();
      empresaSearchController.dispose();

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
    if (cargandoTutores || cargandoEmpresas) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
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
                'Listado de tutores',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Consulta, busca, edita y elimina los tutores registrados.',
                style: TextStyle(color: mutedTextColor(context)),
              ),
              const SizedBox(height: 24),
              Column(
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
              ),
              const SizedBox(height: 24),
              if (tutoresFiltrados.isEmpty)
                Text(
                  'No hay tutores que coincidan con la búsqueda.',
                  style: TextStyle(color: mutedTextColor(context)),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Apellidos')),
                      DataColumn(label: Text('DNI')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Empresa')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: tutoresFiltrados.map((tutor) {
                      return DataRow(
                        cells: [
                          DataCell(Text(tutor.firstName)),
                          DataCell(Text(tutor.lastName)),
                          DataCell(Text(tutor.dni)),
                          DataCell(Text(tutor.email)),
                          DataCell(Text(
                            tutor.companyName.isEmpty
                                ? 'Sin empresa'
                                : tutor.companyName,
                          )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar tutor',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: procesando
                                      ? null
                                      : () => editarTutor(tutor),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar tutor',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: procesando
                                      ? null
                                      : () => borrarTutor(tutor.id),
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

class AgregarTutorTab extends StatefulWidget {
  final String jwt;
  final VoidCallback? onTutorGuardado;

  const AgregarTutorTab({
    super.key,
    required this.jwt,
    this.onTutorGuardado,
  });

  @override
  State<AgregarTutorTab> createState() => _AgregarTutorTabState();
}

class _AgregarTutorTabState extends State<AgregarTutorTab> {
  final _formKey = GlobalKey<FormState>();

  final nombreController = TextEditingController();
  final apellidoController = TextEditingController();
  final dniController = TextEditingController();
  final emailController = TextEditingController();

  final TextEditingController empresaSearchController =
  TextEditingController();

  List<CompanyItem> empresas = [];
  CompanyItem? empresaSeleccionada;
  bool cargandoEmpresas = true;
  bool mostrandoSugerenciasEmpresa = false;

  @override
  void initState() {
    super.initState();
    cargarEmpresas();
  }

  @override
  void dispose() {
    nombreController.dispose();
    apellidoController.dispose();
    dniController.dispose();
    emailController.dispose();
    empresaSearchController.dispose();
    super.dispose();
  }

  Future<void> cargarEmpresas() async {
    setState(() {
      cargandoEmpresas = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/api/companies');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          empresas = data.map((item) => CompanyItem.fromJson(item)).toList();
          cargandoEmpresas = false;
        });
      } else {
        setState(() {
          cargandoEmpresas = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar empresas: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() {
        cargandoEmpresas = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al cargar empresas: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> guardarTutor() async {
    if (_formKey.currentState!.validate()) {
      final url = Uri.parse('http://localhost:8080/api/trainees');

      final body = jsonEncode({
        'firstName': nombreController.text.trim(),
        'lastName': apellidoController.text.trim(),
        'dni': dniController.text.trim(),
        'email': emailController.text.trim(),
        'company': {
          'id': empresaSeleccionada!.id,
        },
      });

      try {
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
              content: Text('Tutor agregado correctamente'),
              backgroundColor: accentColor,
            ),
          );

          nombreController.clear();
          apellidoController.clear();
          dniController.clear();
          emailController.clear();
          empresaSearchController.clear();

          setState(() {
            empresaSeleccionada = null;
            mostrandoSugerenciasEmpresa = false;
          });

          widget.onTutorGuardado?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ${response.statusCode}: ${response.body}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
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

  String? validarTexto(String? value, String campo) {
    if (value == null || value.trim().isEmpty) {
      return 'Introduce $campo';
    }
    return null;
  }

  String? validarEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Introduce el email';
    }

    final email = value.trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!regex.hasMatch(email)) {
      return 'Introduce un email válido';
    }

    return null;
  }

  String? validarEmpresa(CompanyItem? value) {
    if (value == null) {
      return 'Selecciona una empresa';
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

  @override
  Widget build(BuildContext context) {
    final empresasFiltradas = empresas.where((e) {
      final query = empresaSearchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return e.legalName.toLowerCase().contains(query) ||
          e.nif.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
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
                  'Alta de tutor',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Introduce los datos del tutor y asígnalo a una empresa existente.',
                  style: TextStyle(color: mutedTextColor(context)),
                ),
                const SizedBox(height: 24),
                const Text('Nombre'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    hintText: 'Introduce el nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => validarTexto(value, 'el nombre'),
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
                  validator: (value) => validarTexto(value, 'el apellido'),
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
                  validator: (value) => validarTexto(value, 'el DNI'),
                ),
                const SizedBox(height: 16),
                const Text('Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'correo@empresa.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: validarEmail,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Empresa asociada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (cargandoEmpresas)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  TextFormField(
                    controller: empresaSearchController,
                    decoration: const InputDecoration(
                      hintText: 'Empieza a escribir el nombre o NIF',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    onChanged: (value) {
                      setState(() {
                        mostrandoSugerenciasEmpresa = value.trim().isNotEmpty;
                      });
                    },
                    validator: (_) =>
                    empresaSeleccionada == null ? 'Selecciona una empresa' : null,
                  ),
                  if (mostrandoSugerenciasEmpresa)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF111720)
                            : const Color(0xFFF8FAFC),
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
                            title: Text('${e.legalName} (${e.nif})'),
                            onTap: () {
                              setState(() {
                                empresaSeleccionada = e;
                                empresaSearchController.text =
                                '${e.legalName} (${e.nif})';
                                mostrandoSugerenciasEmpresa = false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (empresas.isEmpty)
                    const Text(
                      'No hay empresas registradas. Debes crear una empresa antes de dar de alta un tutor.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                ],
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
                    onPressed: (!cargandoEmpresas && empresas.isNotEmpty)
                        ? guardarTutor
                        : null,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text(
                      'Agregar tutor',
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