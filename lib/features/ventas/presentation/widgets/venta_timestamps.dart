import 'package:flutter/material.dart';

import '../../../../core/utils/business_time.dart';
import '../../data/models/venta_models.dart';

class VentaTimestamps extends StatelessWidget {
  final Venta venta;
  final TextStyle? style;
  final int maxLines;

  const VentaTimestamps({
    super.key,
    required this.venta,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final saleTimeValue = venta.fechaVenta ?? venta.createdAt;
    final registrationTimeValue = venta.registradaAt ?? venta.createdAt;
    final saleTime = formatBusinessDateTime(saleTimeValue);
    final formattedRegistrationTime = formatBusinessDateTime(
      registrationTimeValue,
    );
    final registrationTime = formattedRegistrationTime == saleTime
        ? null
        : formattedRegistrationTime;

    if (saleTime == null && registrationTime == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (saleTime != null)
          Text(
            'Venta: $saleTime',
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        if (registrationTime != null)
          Text(
            'Registrada: $registrationTime',
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
      ],
    );
  }
}
