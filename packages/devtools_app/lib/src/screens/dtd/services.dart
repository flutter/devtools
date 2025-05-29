// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/common_widgets.dart';
import 'dtd_tools_model.dart';

/// Manages business logic for the [ServicesView] widget, which displays
/// information about service methods registered on DTD and provides
/// functionality for calling them.
class ServicesController extends FeatureController {
  late DartToolingDaemon dtd;

  final _services = ValueNotifier<List<DtdServiceMethod>>([]);

  final _selectedService = ValueNotifier<DtdServiceMethod?>(null);

  @override
  void init() {
    super.init();
    unawaited(refresh());
  }

  @override
  void dispose() {
    _services.dispose();
    _selectedService.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final response = await dtd.getRegisteredServices();
    _services.value = <DtdServiceMethod>[
      ...response.dtdServices.map((value) {
        // If the DTD service has the form 'service.method', split up the two
        // values. Otherwise, leave the service null and use the entire name
        // as the method.
        String? service;
        String method;
        final parts = value.split('.');
        if (parts.length > 1) {
          service = parts[0];
        }
        method = parts.last;
        return DtdServiceMethod(service: service, method: method);
      }),
      for (final service in response.clientServices) ...[
        for (final method in service.methods.values)
          DtdServiceMethod(
            service: service.name,
            method: method.name,
            capabilities: method.capabilities,
          ),
      ],
    ];
  }
}

/// Displays information about service methods registered on DTD and provides
/// functionality for calling them.
class ServicesView extends StatelessWidget {
  const ServicesView({super.key, required this.controller});

  final ServicesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return FlexSplitColumn(
          totalHeight: constraints.maxHeight,
          initialFractions: const [0.6, 0.4],
          minSizes: const [100.0, 200.0],
          headers: [
            AreaPaneHeader(
              title: Text('Registered services', style: theme.boldTextStyle),
              roundedTopBorder: false,
              includeTopBorder: false,
              tall: true,
              actions: [
                DevToolsButton.iconOnly(
                  icon: Icons.refresh,
                  onPressed: controller.refresh,
                ),
              ],
            ),
            AreaPaneHeader(
              title: Text('Manually call service', style: theme.boldTextStyle),
              roundedTopBorder: false,
              tall: true,
            ),
          ],
          children: [
            MultiValueListenableBuilder(
              listenables: [controller._services, controller._selectedService],
              builder: (context, values, _) {
                final services = values.first as List<DtdServiceMethod>;
                final selectedService = values.second as DtdServiceMethod?;
                final sortedServices = services.toList()..sort();
                return Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    primary: true,
                    itemCount: sortedServices.length,
                    itemBuilder: (context, index) {
                      final service = sortedServices[index];
                      return ListTile(
                        title: Text(
                          service.displayName,
                          style: theme.regularTextStyle,
                        ),
                        selected: selectedService == service,
                        onTap: () {
                          controller._selectedService.value = service;
                        },
                      );
                    },
                  ),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: controller._selectedService,
              builder: (context, service, child) {
                return _ManuallyCallService(
                  serviceMethod: service,
                  dtd: controller.dtd,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// A widget that provides support for manually calling a DTD service method and
/// viewing the result.
class _ManuallyCallService extends StatefulWidget {
  const _ManuallyCallService({required this.serviceMethod, required this.dtd});

  final DtdServiceMethod? serviceMethod;

  final DartToolingDaemon dtd;

  @override
  State<_ManuallyCallService> createState() => _ManuallyCallServiceState();
}

class _ManuallyCallServiceState extends State<_ManuallyCallService> {
  final serviceController = TextEditingController();
  final methodController = TextEditingController();
  final paramsController = TextEditingController();

  Map<String, Object?>? callResult;

  @override
  void initState() {
    super.initState();
    _maybePopulateSelectedService();
  }

  @override
  void didUpdateWidget(covariant _ManuallyCallService oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceMethod != widget.serviceMethod) {
      callResult = null;
      _maybePopulateSelectedService();
    }
  }

  @override
  void dispose() {
    serviceController.dispose();
    methodController.dispose();
    paramsController.dispose();
    super.dispose();
  }

  void _maybePopulateSelectedService() {
    if (widget.serviceMethod != null) {
      serviceController.text = widget.serviceMethod!.service ?? '';
      methodController.text = widget.serviceMethod!.method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Service', serviceController, 'service_name'),
          const SizedBox(height: denseSpacing),
          _buildTextField('Method', methodController, 'method_name'),
          const SizedBox(height: denseSpacing),
          Row(
            children: [
              const Text('Additional parameters (JSON encoded):'),
              const SizedBox(width: defaultSpacing),
              Expanded(
                child: DevToolsClearableTextField(
                  controller: paramsController,
                  hintText: '{"foo":"bar"}',
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DevToolsButton(
                label: 'Clear',
                onPressed: () {
                  setState(() {
                    callResult = null;
                    serviceController.clear();
                    methodController.clear();
                    paramsController.clear();
                  });
                },
              ),
              const SizedBox(width: denseSpacing),
              DevToolsButton(
                elevated: true,
                label: 'Call Service',
                onPressed: _callService,
              ),
            ],
          ),
          const PaddedDivider.thin(),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                callResult == null
                    ? 'Call the service to view the response'
                    : callResult.toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hintText,
  ) {
    return Row(
      children: [
        SizedBox(width: 150, child: Text('$label:')),
        Expanded(
          child: DevToolsClearableTextField(
            controller: controller,
            hintText: hintText,
          ),
        ),
      ],
    );
  }

  Future<void> _callService() async {
    if (methodController.text.isEmpty) {
      notificationService.push('Method is required');
      return;
    }

    Map<String, Object?>? params;
    try {
      if (paramsController.text.isNotEmpty) {
        try {
          params = (jsonDecode(paramsController.text) as Map)
              .cast<String, Object?>();
        } catch (e) {
          notificationService.push(
            'Failed to JSON decode parameters: "${paramsController.text}"',
          );
          return;
        }
      }
      final response = await widget.dtd.call(
        serviceController.text.isNotEmpty ? serviceController.text : null,
        methodController.text,
        params: params,
      );
      setState(() {
        callResult = response.result;
      });
    } catch (e) {
      setState(() {
        callResult = {'error': e.toString()};
      });
    }
  }
}
