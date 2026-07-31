import "dart:ui";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../../../core/theme/app_colors.dart";
import "../../../../core/theme/app_text_styles.dart";
import "../../../../core/theme/app_dimensions.dart";
import "../../../../core/utils/format_utils.dart";
import "../../../auth/presentation/providers/auth_provider.dart";

class _NavItem { final String path,label; final IconData icon,activeIcon;
  const _NavItem({required this.path,required this.label,required this.icon,required this.activeIcon}); }
const _nav = [
  _NavItem(path:'/dashboard',label:'Inicio',icon:Icons.home_outlined,activeIcon:Icons.home_rounded),
  _NavItem(path:'/ventas',label:'Ventas',icon:Icons.point_of_sale_outlined,activeIcon:Icons.point_of_sale_rounded),
  _NavItem(path:'/inventario',label:'Stock',icon:Icons.inventory_2_outlined,activeIcon:Icons.inventory_2_rounded),
  _NavItem(path:'/perfil',label:'Perfil',icon:Icons.person_outline_rounded,activeIcon:Icons.person_rounded),
];
class _DItem { final String path,label; final IconData icon; final String? perm;
  const _DItem({required this.path,required this.label,required this.icon,this.perm}); }
class _DSec { final String title; final List<_DItem> items;
  const _DSec({required this.title,required this.items}); }
const _drawer = [
  _DSec(title:'PRINCIPAL',items:[_DItem(path:'/dashboard',label:'Dashboard',icon:Icons.home_rounded)]),
  _DSec(title:'VENTAS Y CAJA',items:[
    _DItem(path:'/ventas',label:'Punto de Venta',icon:Icons.point_of_sale_rounded),
    _DItem(path:'/caja',label:'Caja',icon:Icons.account_balance_rounded),
  ]),
  _DSec(title:'INVENTARIO',items:[
    _DItem(path:'/productos',label:'Productos',icon:Icons.local_bar_rounded),
    _DItem(path:'/inventario',label:'Inventario',icon:Icons.inventory_2_rounded),
    _DItem(path:'/kardex',label:'Kardex',icon:Icons.swap_vert_rounded),
    _DItem(path:'/compras',label:'Compras',icon:Icons.shopping_cart_rounded),
  ]),
  _DSec(title:'PERSONAL',items:[_DItem(path:'/asistencia',label:'Asistencia',icon:Icons.calendar_today_rounded)]),
  _DSec(title:'ADMINISTRACION',items:[
    _DItem(path:'/usuarios',label:'Usuarios',icon:Icons.people_rounded,perm:'usuarios:leer'),
    _DItem(path:'/sucursales',label:'Sucursales',icon:Icons.store_rounded,perm:'establecimientos:leer'),
    _DItem(path:'/roles',label:'Roles',icon:Icons.admin_panel_settings_rounded,perm:'roles:leer'),
    _DItem(path:'/permisos',label:'Permisos',icon:Icons.security_rounded,perm:'permisos:leer'),
    _DItem(path:'/auditoria',label:'Auditoria',icon:Icons.history_rounded,perm:'audit:leer'),
  ]),
];

class ShellScreen extends ConsumerWidget {
  final Widget child; final String currentPath;
  const ShellScreen({super.key,required this.child,required this.currentPath});
  @override Widget build(BuildContext context,WidgetRef ref) {
    final auth=ref.watch(authProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:const SystemUiOverlayStyle(statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.dark,
          systemNavigationBarColor:Colors.white,systemNavigationBarIconBrightness:Brightness.dark),
      child:Scaffold(backgroundColor:AppColors.backgroundAlt,
        drawer:_Drawer(current:currentPath,auth:auth,go:(p)=>context.go(p),logout:()=>ref.read(authProvider.notifier).logout()),
        body:child,
        bottomNavigationBar:_NavBar(current:currentPath,go:(p)=>context.go(p))));
  }
}

class _NavBar extends StatelessWidget {
  final String current; final ValueChanged<String> go;
  const _NavBar({required this.current,required this.go});
  @override Widget build(BuildContext context) {
    final bot=MediaQuery.of(context).padding.bottom;
    return Padding(padding:EdgeInsets.only(left:12,right:12,bottom:bot+10),
      child:Container(height:68,decoration:BoxDecoration(
          color:Colors.white.withOpacity(0.95),borderRadius:BorderRadius.circular(30),
          border:Border.all(color:AppColors.primary.withOpacity(0.08)),boxShadow:AppShadows.nav),
        child:ClipRRect(borderRadius:BorderRadius.circular(30),
          child:BackdropFilter(filter:ImageFilter.blur(sigmaX:20,sigmaY:20),
            child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,
              children:_nav.map((item){
                final on=current.startsWith(item.path);
                return GestureDetector(onTap:(){HapticFeedback.lightImpact();go(item.path);},
                  behavior:HitTestBehavior.opaque,
                  child:AnimatedContainer(duration:const Duration(milliseconds:250),
                    curve:Curves.easeOutCubic,
                    padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
                    decoration:BoxDecoration(
                      color:on?AppColors.primary.withOpacity(0.12):Colors.transparent,
                      borderRadius:BorderRadius.circular(16)),
                    child:Column(mainAxisSize:MainAxisSize.min,children:[
                      AnimatedSwitcher(duration:const Duration(milliseconds:200),
                        child:Icon(on?item.activeIcon:item.icon,key:ValueKey(on),
                          color:on?AppColors.navActive:AppColors.navInactive,size:22)),
                      const SizedBox(height:3),
                      Text(item.label,style:TextStyle(fontSize:10.5,
                          fontWeight:on?FontWeight.w700:FontWeight.w400,
                          color:on?AppColors.navActive:AppColors.navInactive)),
                    ])));
              }).toList())))));
  }
}

class _Drawer extends StatelessWidget {
  final String current; final AuthState auth; final ValueChanged<String> go; final VoidCallback logout;
  const _Drawer({required this.current,required this.auth,required this.go,required this.logout});
  @override Widget build(BuildContext context) {
    final u=auth.user; final un=u?.username??'';
    return Drawer(backgroundColor:AppColors.surface,child:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.all(16),child:Row(children:[
        CircleAvatar(radius:26,backgroundColor:AppColors.avatarColor(un),
          child:Text(FormatUtils.initials(un),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:16))),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(un,style:AppTextStyles.titleMedium,overflow:TextOverflow.ellipsis),
          Text(FormatUtils.roleName(u?.rol??''),style:AppTextStyles.bodySmall),
        ])),
        Container(width:36,height:36,decoration:BoxDecoration(color:AppColors.primarySurface,borderRadius:BorderRadius.circular(8)),
          child:const Icon(Icons.local_bar_rounded,color:AppColors.primary,size:20)),
      ])),
      const Divider(height:1),
      Expanded(child:ListView(padding:const EdgeInsets.symmetric(vertical:8),children:[
        for(final sec in _drawer)...[
          Padding(padding:const EdgeInsets.fromLTRB(16,14,16,4),
            child:Text(sec.title,style:AppTextStyles.labelSmall.copyWith(letterSpacing:0.8,color:AppColors.textTertiary))),
          for(final item in sec.items)
            if(item.perm==null||auth.hasPermission(item.perm!))
              _DNav(item:item,on:current.startsWith(item.path),tap:(){Navigator.of(context).pop();go(item.path);}),
        ],
      ])),
      const Divider(height:1),
      ListTile(dense:true,
        leading:const Icon(Icons.logout_rounded,color:AppColors.error,size:20),
        title:Text('Cerrar sesion',style:AppTextStyles.bodyMedium.copyWith(color:AppColors.error,fontWeight:FontWeight.w500)),
        onTap:(){ Navigator.of(context).pop(); logout(); }),
      const SizedBox(height:8),
    ])));
  }
}
class _DNav extends StatelessWidget {
  final _DItem item; final bool on; final VoidCallback tap;
  const _DNav({required this.item,required this.on,required this.tap});
  @override Widget build(BuildContext context) => Container(
    margin:const EdgeInsets.symmetric(horizontal:8,vertical:1),
    decoration:BoxDecoration(color:on?AppColors.primarySurface:Colors.transparent,borderRadius:BorderRadius.circular(AppRadius.sm)),
    child:ListTile(dense:true,
      leading:Icon(item.icon,size:20,color:on?AppColors.primary:AppColors.textSecondary),
      title:Text(item.label,style:TextStyle(fontSize:14,fontWeight:on?FontWeight.w600:FontWeight.w400,color:on?AppColors.primary:AppColors.textPrimary)),
      onTap:tap,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(AppRadius.sm))));
}
