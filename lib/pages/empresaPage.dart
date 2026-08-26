import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;
import '../config/api_config.dart';

const Color accentColor = Color(0xFF3ECF8E);

class RepresentanteData {
  final TextEditingController nombreController;
  final TextEditingController dniController;

  RepresentanteData()
      : nombreController = TextEditingController(),
        dniController = TextEditingController();

  void dispose() {
    nombreController.dispose();
    dniController.dispose();
  }
}

class CompanyItem {
  final int id;
  final String nif;
  final String legalName;
  final String activity;
  final String street;
  final String postalCode;
  final String city;
  final String province;
  final String country;
  final String phone;
  final String agreementNumber;
  final String agreementDate;
  final List<RepresentanteData> representatives;

  CompanyItem({
    required this.id,
    required this.nif,
    required this.legalName,
    required this.activity,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.province,
    required this.country,
    required this.phone,
    required this.agreementNumber,
    required this.agreementDate,
    this.representatives = const [],
  });

  factory CompanyItem.fromJson(Map<String, dynamic> json) {
    final agreementData = json['agreement'];

    Map<String, dynamic>? agreementJson;
    if (agreementData is Map<String, dynamic>) {
      agreementJson = agreementData;
    }

    final representativesJson = json['representatives'] as List<dynamic>? ?? [];
    final representatives = <RepresentanteData>[];

    for (final rep in representativesJson) {
      if (rep is Map<String, dynamic>) {
        final repData = RepresentanteData();
        repData.nombreController.text = rep['fullName']?.toString() ?? '';
        repData.dniController.text = rep['dni']?.toString() ?? '';
        representatives.add(repData);
      }
    }

    return CompanyItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      nif: json['nif']?.toString() ?? '',
      legalName: json['legalName']?.toString() ?? '',
      activity: json['activity']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      postalCode: json['postalCode']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      agreementNumber: agreementJson?['number']?.toString() ?? '',
      agreementDate: agreementJson?['signDate']?.toString() ?? '',
      representatives: representatives,
    );
  }
}

class EmpresasPage extends StatefulWidget {
  final String jwt;

  const EmpresasPage({super.key, required this.jwt});

  @override
  State<EmpresasPage> createState() => _EmpresasPageState();
}

class _EmpresasPageState extends State<EmpresasPage> {
  final GlobalKey<ListadoEmpresasTabState> listadoKey =
  GlobalKey<ListadoEmpresasTabState>();

  void refrescarListado() {
    listadoKey.currentState?.cargarEmpresas();
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
                  icon: Icon(Icons.business_center_outlined),
                  text: 'Agregar',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListadoEmpresasTab(
                  key: listadoKey,
                  jwt: widget.jwt,
                ),
                AgregarEmpresaTab(
                  jwt: widget.jwt,
                  onEmpresaGuardada: refrescarListado,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListadoEmpresasTab extends StatefulWidget {
  final String jwt;

  const ListadoEmpresasTab({super.key, required this.jwt});

  @override
  State<ListadoEmpresasTab> createState() => ListadoEmpresasTabState();
}

class ListadoEmpresasTabState extends State<ListadoEmpresasTab> {
  List<CompanyItem> empresas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarEmpresas();
  }

  Future<void> cargarEmpresas() async {
    setState(() {
      cargando = true;
    });

    try {
      final url = Uri.parse(ApiConfig.companies);

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
          empresas = data.map((json) => CompanyItem.fromJson(json)).toList();
          cargando = false;
        });
      } else {
        setState(() {
          cargando = false;
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
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String formatearFecha(String fechaIso) {
    if (fechaIso.trim().isEmpty) return '-';

    try {
      final fecha = DateTime.parse(fechaIso);
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final anio = fecha.year.toString();
      return '$dia/$mes/$anio';
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

  Future<void> editarEmpresa(CompanyItem empresa) async {
    final nifController = TextEditingController(text: empresa.nif);
    final nombreLegalController = TextEditingController(text: empresa.legalName);
    final actividadController = TextEditingController(text: empresa.activity);
    final calleController = TextEditingController(text: empresa.street);
    final cpController = TextEditingController(text: empresa.postalCode);
    final provinciaController = TextEditingController(text: empresa.province);
    final localidadController = TextEditingController(text: empresa.city);
    final paisController = TextEditingController(text: empresa.country);
    final telefonoController = TextEditingController(text: empresa.phone);

    final representantes = <RepresentanteData>[];
    for (final rep in empresa.representatives) {
      representantes.add(RepresentanteData());
      representantes.last.nombreController.text = rep.nombreController.text;
      representantes.last.dniController.text = rep.dniController.text;
    }

    if (representantes.isEmpty) {
      representantes.add(RepresentanteData());
    }

    final formKey = GlobalKey<FormState>();
    final List<String> provincias = const [
      'Álava', 'Albacete', 'Alicante', 'Almería', 'Asturias', 'Ávila',
      'Badajoz', 'Barcelona', 'Burgos', 'Cáceres', 'Cádiz', 'Cantabria',
      'Castellón', 'Ciudad Real', 'Córdoba', 'La Coruña', 'Cuenca',
      'Gerona', 'Granada', 'Guadalajara', 'Guipúzcoa', 'Huelva', 'Huesca',
      'Islas Baleares', 'Jaén', 'León', 'Lérida', 'Lugo', 'Madrid',
      'Málaga', 'Murcia', 'Navarra', 'Orense', 'Palencia', 'Las Palmas',
      'Pontevedra', 'La Rioja', 'Salamanca', 'Segovia', 'Sevilla', 'Soria',
      'Tarragona', 'Santa Cruz de Tenerife', 'Teruel', 'Toledo', 'Valencia',
      'Valladolid', 'Vizcaya', 'Zamora', 'Zaragoza',
    ];

    bool mostrandoSugerenciasProvincia = false;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar empresa'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nifController,
                          decoration: const InputDecoration(
                            labelText: 'NIF',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el NIF'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nombreLegalController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre legal',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el nombre legal'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: actividadController,
                          decoration: const InputDecoration(
                            labelText: 'Actividad',
                            prefixIcon: Icon(Icons.work_outline),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce la actividad'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: calleController,
                          decoration: const InputDecoration(
                            labelText: 'Calle',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce la calle'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cpController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Código postal',
                                  prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                                ),
                                validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Introduce el CP'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: provinciaController,
                                decoration: const InputDecoration(
                                  labelText: 'Provincia',
                                  prefixIcon: Icon(Icons.map_outlined),
                                ),
                                onChanged: (value) {
                                  setStateDialog(() {
                                    mostrandoSugerenciasProvincia = value.trim().isNotEmpty;
                                  });
                                },
                                validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Introduce la provincia'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        if (mostrandoSugerenciasProvincia)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 150),
                            decoration: BoxDecoration(
                              color: surfaceColor(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderThemeColor(context)),
                            ),
                            child: ListView.builder(
                              itemCount: provincias.length,
                              itemBuilder: (context, index) {
                                final p = provincias[index];
                                return ListTile(
                                  title: Text(p),
                                  onTap: () {
                                    setStateDialog(() {
                                      provinciaController.text = p;
                                      mostrandoSugerenciasProvincia = false;
                                      if (localidadController.text.trim().isEmpty) {
                                        localidadController.text = p;
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: localidadController,
                          decoration: const InputDecoration(
                            labelText: 'Localidad',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce la localidad'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: paisController,
                          decoration: const InputDecoration(
                            labelText: 'País',
                            prefixIcon: Icon(Icons.public_outlined),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el país'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: telefonoController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Introduce el teléfono'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Representantes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        ...List.generate(representantes.length, (index) {
                          return Card(
                            margin: const EdgeInsets.only(top: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text('Representante ${index + 1}'),
                                      const Spacer(),
                                      if (representantes.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          onPressed: () {
                                            setStateDialog(() {
                                              representantes[index].dispose();
                                              representantes.removeAt(index);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: representantes[index].nombreController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: representantes[index].dniController,
                                    decoration: const InputDecoration(
                                      labelText: 'DNI',
                                      prefixIcon: Icon(Icons.credit_card_outlined),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: () {
                            setStateDialog(() {
                              representantes.add(RepresentanteData());
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir representante'),
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
      nifController.dispose();
      nombreLegalController.dispose();
      actividadController.dispose();
      calleController.dispose();
      cpController.dispose();
      provinciaController.dispose();
      localidadController.dispose();
      paisController.dispose();
      telefonoController.dispose();
      for (final rep in representantes) {
        rep.dispose();
      }
      return;
    }

    setState(() {
      cargando = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.companies}/${empresa.id}');

      final body = jsonEncode({
        'nif': nifController.text.trim(),
        'legalName': nombreLegalController.text.trim(),
        'activity': actividadController.text.trim(),
        'street': calleController.text.trim(),
        'postalCode': cpController.text.trim(),
        'city': provinciaController.text.trim(),
        'province': localidadController.text.trim(),
        'country': paisController.text.trim(),
        'phone': telefonoController.text.trim(),
        'representatives': representantes.map((rep) {
          return {
            'fullName': rep.nombreController.text.trim(),
            'dni': rep.dniController.text.trim(),
          };
        }).toList(),
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
            content: Text('Empresa actualizada correctamente'),
            backgroundColor: accentColor,
          ),
        );
        await cargarEmpresas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${response.body}'),
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
    } finally {
      setState(() {
        cargando = false;
      });

      nifController.dispose();
      nombreLegalController.dispose();
      actividadController.dispose();
      calleController.dispose();
      cpController.dispose();
      provinciaController.dispose();
      localidadController.dispose();
      paisController.dispose();
      telefonoController.dispose();
      for (final rep in representantes) {
        rep.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (empresas.isEmpty) {
      return Center(
        child: Text(
          'No hay empresas registradas.',
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
                'Listado de empresas',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Consulta las empresas registradas en la aplicación y su convenio asociado.',
                style: TextStyle(color: mutedTextColor(context)),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 700;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: empresas.length,
                    itemBuilder: (context, index) {
                      final empresa = empresas[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: surfaceColor(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: borderThemeColor(context),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: accentColor.withOpacity(0.15),
                                    child: const Icon(
                                      Icons.business_outlined,
                                      color: accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          empresa.legalName.isEmpty
                                              ? 'Sin nombre'
                                              : empresa.legalName,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          empresa.nif.isEmpty
                                              ? 'Sin NIF'
                                              : 'NIF: ${empresa.nif}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: mutedTextColor(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    tooltip: 'Acciones',
                                    onSelected: (value) {
                                      if (value == 'editar') {
                                        editarEmpresa(empresa);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'editar',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.edit_outlined),
                                          title: Text('Editar'),
                                        ),
                                      ),
                                    ],
                                    icon: const Icon(Icons.more_vert),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      empresa.activity.isEmpty
                                          ? 'Sin actividad'
                                          : empresa.activity,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                  if (empresa.agreementNumber.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Convenio: ${empresa.agreementNumber}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (isMobile)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _companyInfoLine(
                                      context,
                                      Icons.location_on_outlined,
                                      empresa.street.isEmpty
                                          ? 'Sin dirección'
                                          : empresa.street,
                                    ),
                                    const SizedBox(height: 7),
                                    _companyInfoLine(
                                      context,
                                      Icons.markunread_mailbox_outlined,
                                      '${empresa.postalCode} ${empresa.city}'.trim().isEmpty
                                          ? 'Sin CP/localidad'
                                          : '${empresa.postalCode} ${empresa.city}',
                                    ),
                                    const SizedBox(height: 7),
                                    _companyInfoLine(
                                      context,
                                      Icons.map_outlined,
                                      empresa.province.isEmpty
                                          ? 'Sin provincia'
                                          : empresa.province,
                                    ),
                                    const SizedBox(height: 7),
                                    _companyInfoLine(
                                      context,
                                      Icons.phone_outlined,
                                      empresa.phone.isEmpty
                                          ? 'Sin teléfono'
                                          : empresa.phone,
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _companyInfoLine(
                                        context,
                                        Icons.location_on_outlined,
                                        empresa.street.isEmpty
                                            ? 'Sin dirección'
                                            : empresa.street,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _companyInfoLine(
                                        context,
                                        Icons.markunread_mailbox_outlined,
                                        '${empresa.postalCode} ${empresa.city}'.trim().isEmpty
                                            ? 'Sin CP/localidad'
                                            : '${empresa.postalCode} ${empresa.city}',
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _companyInfoLine(
                                        context,
                                        Icons.map_outlined,
                                        empresa.province.isEmpty
                                            ? 'Sin provincia'
                                            : empresa.province,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _companyInfoLine(
                                        context,
                                        Icons.phone_outlined,
                                        empresa.phone.isEmpty
                                            ? 'Sin teléfono'
                                            : empresa.phone,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _companyInfoLine(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: mutedTextColor(context),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: mutedTextColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

class AgregarEmpresaTab extends StatefulWidget {
  final String jwt;
  final VoidCallback? onEmpresaGuardada;

  const AgregarEmpresaTab({
    super.key,
    required this.jwt,
    this.onEmpresaGuardada,
  });

  @override
  State<AgregarEmpresaTab> createState() => _AgregarEmpresaTabState();
}

class _AgregarEmpresaTabState extends State<AgregarEmpresaTab> {
  final _formKey = GlobalKey<FormState>();

  final nifController = TextEditingController();
  final nombreLegalController = TextEditingController();
  final actividadController = TextEditingController();
  final calleController = TextEditingController();
  final cpController = TextEditingController();
  final provinciaController = TextEditingController();
  final localidadController = TextEditingController();
  final paisController = TextEditingController(text: 'España');
  final telefonoController = TextEditingController();

  final List<RepresentanteData> representantes = [RepresentanteData()];

  bool procesandoCsv = false;
  bool mostrandoSugerenciasProvincia = false;

  final List<String> _provincias = const [
    'Álava', 'Albacete', 'Alicante', 'Almería', 'Asturias', 'Ávila',
    'Badajoz', 'Barcelona', 'Burgos', 'Cáceres', 'Cádiz', 'Cantabria',
    'Castellón', 'Ciudad Real', 'Córdoba', 'La Coruña', 'Cuenca',
    'Gerona', 'Granada', 'Guadalajara', 'Guipúzcoa', 'Huelva', 'Huesca',
    'Islas Baleares', 'Jaén', 'León', 'Lérida', 'Lugo', 'Madrid',
    'Málaga', 'Murcia', 'Navarra', 'Orense', 'Palencia', 'Las Palmas',
    'Pontevedra', 'La Rioja', 'Salamanca', 'Segovia', 'Sevilla', 'Soria',
    'Tarragona', 'Santa Cruz de Tenerife', 'Teruel', 'Toledo', 'Valencia',
    'Valladolid', 'Vizcaya', 'Zamora', 'Zaragoza',
  ];

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

  @override
  void dispose() {
    nifController.dispose();
    nombreLegalController.dispose();
    actividadController.dispose();
    calleController.dispose();
    cpController.dispose();
    provinciaController.dispose();
    localidadController.dispose();
    paisController.dispose();
    telefonoController.dispose();

    for (final representante in representantes) {
      representante.dispose();
    }

    super.dispose();
  }

  void agregarRepresentante() {
    setState(() {
      representantes.add(RepresentanteData());
    });
  }

  void eliminarRepresentante(int index) {
    if (representantes.length == 1) return;

    setState(() {
      representantes[index].dispose();
      representantes.removeAt(index);
    });
  }

  Future<void> guardarEmpresa() async {
    if (_formKey.currentState!.validate()) {
      final url = Uri.parse(ApiConfig.companies);

      final body = jsonEncode({
        'nif': nifController.text.trim(),
        'legalName': nombreLegalController.text.trim(),
        'activity': actividadController.text.trim(),
        'street': calleController.text.trim(),
        'postalCode': cpController.text.trim(),
        'city': provinciaController.text.trim(),
        'province': localidadController.text.trim(),
        'country': paisController.text.trim(),
        'phone': telefonoController.text.trim(),
        'representatives': representantes.map((representante) {
          return {
            'fullName': representante.nombreController.text.trim(),
            'dni': representante.dniController.text.trim(),
          };
        }).toList(),
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
              content: Text('Empresa agregada correctamente'),
              backgroundColor: accentColor,
            ),
          );

          nifController.clear();
          nombreLegalController.clear();
          actividadController.clear();
          calleController.clear();
          cpController.clear();
          provinciaController.clear();
          localidadController.clear();
          paisController.text = 'España';
          telefonoController.clear();

          for (final representante in representantes) {
            representante.dispose();
          }

          representantes.clear();
          representantes.add(RepresentanteData());

          setState(() {});

          widget.onEmpresaGuardada?.call();
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

  Future<void> subirCsvEmpresas() async {
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

      final uri = Uri.parse(ApiConfig.companiesUpload);

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
            content: Text('CSV de empresas procesado correctamente'),
            backgroundColor: accentColor,
          ),
        );
        widget.onEmpresaGuardada?.call();
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

  Future<void> descargarPlantillaEmpresasCsv() async {
    try {
      final url = Uri.parse(ApiConfig.companiesTemplate);

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
          ..download = 'plantilla_empresas.csv'
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

  @override
  Widget build(BuildContext context) {
    final provinciasFiltradas = _provincias.where((p) {
      final query = provinciaController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return p.toLowerCase().contains(query);
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
                  'Alta de empresa',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Introduce los datos de la empresa y sus representantes legales, o utiliza un fichero CSV. El convenio se puede indicar en el CSV o se generará automáticamente.',
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
                        onPressed: procesandoCsv ? null : subirCsvEmpresas,
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
                        onPressed: descargarPlantillaEmpresasCsv,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Descargar plantilla'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('NIF'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nifController,
                  decoration: const InputDecoration(
                    hintText: 'B12345678',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => validarTexto(value, 'el NIF'),
                ),
                const SizedBox(height: 16),
                const Text('Nombre legal de la empresa'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nombreLegalController,
                  decoration: const InputDecoration(
                    hintText: 'Introduce el nombre legal',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (value) =>
                      validarTexto(value, 'el nombre legal de la empresa'),
                ),
                const SizedBox(height: 16),
                const Text('Actividad'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: actividadController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Desarrollo de software',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  validator: (value) => validarTexto(value, 'la actividad'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Dirección',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text('Calle'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: calleController,
                  decoration: const InputDecoration(
                    hintText: 'Calle, número, piso...',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => validarTexto(value, 'la calle'),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 650;

                    final cpField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Código postal'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: cpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '28922',
                            prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                          ),
                          validator: (value) =>
                              validarTexto(value, 'el código postal'),
                        ),
                      ],
                    );

                    final provinciaField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Provincia'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: provinciaController,
                          decoration: const InputDecoration(
                            hintText: 'Madrid',
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                          onChanged: (value) {
                            setState(() {
                              mostrandoSugerenciasProvincia =
                                  value.trim().isNotEmpty;
                            });
                          },
                          validator: (value) =>
                              validarTexto(value, 'la provincia'),
                        ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: cpField),
                          const SizedBox(width: 16),
                          Expanded(child: provinciaField),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cpField,
                        const SizedBox(height: 16),
                        provinciaField,
                      ],
                    );
                  },
                ),
                if (mostrandoSugerenciasProvincia)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: innerCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderThemeColor(context)),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: provinciasFiltradas.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No hay provincias que coincidan'),
                    )
                        : ListView.builder(
                      itemCount: provinciasFiltradas.length,
                      itemBuilder: (context, index) {
                        final p = provinciasFiltradas[index];
                        return ListTile(
                          title: Text(p),
                          onTap: () {
                            setState(() {
                              provinciaController.text = p;
                              mostrandoSugerenciasProvincia = false;

                              if (localidadController.text
                                  .trim()
                                  .isEmpty) {
                                localidadController.text = p;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('Localidad'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: localidadController,
                  decoration: const InputDecoration(
                    hintText: 'Getafe',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  validator: (value) => validarTexto(value, 'la localidad'),
                ),
                const SizedBox(height: 16),
                const Text('País'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: paisController,
                  decoration: const InputDecoration(
                    hintText: 'España',
                    prefixIcon: Icon(Icons.public_outlined),
                  ),
                  validator: (value) => validarTexto(value, 'el país'),
                ),
                const SizedBox(height: 16),
                const Text('Teléfono'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '600123123',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => validarTexto(value, 'el teléfono'),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Representantes legales',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: agregarRepresentante,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(representantes.length, (index) {
                  final representante = representantes[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: innerCardColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderThemeColor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Representante ${index + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (representantes.length > 1)
                              IconButton(
                                onPressed: () => eliminarRepresentante(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Nombre completo'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: representante.nombreController,
                          decoration: const InputDecoration(
                            hintText: 'Nombre del representante',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              validarTexto(value, 'el nombre del representante'),
                        ),
                        const SizedBox(height: 16),
                        const Text('DNI'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: representante.dniController,
                          decoration: const InputDecoration(
                            hintText: '12345678A',
                            prefixIcon: Icon(Icons.credit_card_outlined),
                          ),
                          validator: (value) =>
                              validarTexto(value, 'el DNI del representante'),
                        ),
                      ],
                    ),
                  );
                }),
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
                    onPressed: guardarEmpresa,
                    icon: const Icon(Icons.business_center_outlined),
                    label: const Text(
                      'Agregar empresa',
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