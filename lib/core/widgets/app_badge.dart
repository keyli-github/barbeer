import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RoleBadge extends StatelessWidget {
  final String role; const RoleBadge({super.key,required this.role});
  @override Widget build(BuildContext context) {
    final c=AppColors.roleColor(role);
    return Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
        decoration:BoxDecoration(color:c.withOpacity(0.12),borderRadius:BorderRadius.circular(100)),
        child:Text(role,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:c)));
  }
}

class StatusBadge extends StatelessWidget {
  final bool activo; const StatusBadge({super.key,required this.activo});
  @override Widget build(BuildContext context) {
    final c=activo?AppColors.success:AppColors.textTertiary;
    return Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
        decoration:BoxDecoration(color:c.withOpacity(0.12),borderRadius:BorderRadius.circular(100)),
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          Container(width:6,height:6,decoration:BoxDecoration(color:c,shape:BoxShape.circle)),
          const SizedBox(width:5),
          Text(activo?'Activo':'Inactivo',style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:c)),
        ]));
  }
}

class PermissionModuleBadge extends StatelessWidget {
  final String module; const PermissionModuleBadge({super.key,required this.module});
  static const _c = {'usuarios':Color(0xFF2563EB),'roles':Color(0xFF8B5CF6),'permisos':Color(0xFFF59E0B),'audit':Color(0xFF10B981),'establecimientos':Color(0xFFF97316)};
  @override Widget build(BuildContext context) {
    final c=_c[module.toLowerCase()]??const Color(0xFF2563EB);
    return Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
        decoration:BoxDecoration(color:c.withOpacity(0.12),borderRadius:BorderRadius.circular(100)),
        child:Text(module,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:c)));
  }
}

class AuditActionBadge extends StatelessWidget {
  final String action; const AuditActionBadge({super.key,required this.action});
  @override Widget build(BuildContext context) {
    Color c;
    if(action.contains('LOGIN')||action.contains('SESION')) c=const Color(0xFF2563EB);
    else if(action.contains('CREAR')) c=const Color(0xFF10B981);
    else if(action.contains('EDITAR')||action.contains('CAMBIAR')||action.contains('ASIGNAR')||action.contains('RESETEAR')) c=const Color(0xFFF59E0B);
    else c=const Color(0xFFEF4444);
    return Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
        decoration:BoxDecoration(color:c.withOpacity(0.12),borderRadius:BorderRadius.circular(100)),
        child:Text(action.replaceAll('_',' '),style:TextStyle(fontSize:10,fontWeight:FontWeight.w600,color:c),overflow:TextOverflow.ellipsis));
  }
}

class CountBadge extends StatelessWidget {
  final int count; final Color? color; const CountBadge({super.key,required this.count,this.color});
  @override Widget build(BuildContext context) => Container(width:22,height:22,
    decoration:BoxDecoration(color:color??AppColors.error,shape:BoxShape.circle),
    child:Center(child:Text(count>99?'99+':'$count',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:Colors.white))));
}
