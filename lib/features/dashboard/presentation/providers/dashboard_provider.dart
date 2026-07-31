import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';

class DashboardData {
  final List roles,sedes,audit,sessions,users;
  const DashboardData({this.roles=const[],this.sedes=const[],this.audit=const[],this.sessions=const[],this.users=const[]});
}
class DashboardState {
  final bool isLoading; final String? error; final DashboardData? data;
  const DashboardState({this.isLoading=false,this.error,this.data});
}
class DashboardNotifier extends StateNotifier<DashboardState> {
  final ApiClient _api;
  DashboardNotifier(this._api):super(const DashboardState()){load();}
  Future<void> load() async {
    state=const DashboardState(isLoading:true);
    try {
      Future<List> get(String path,[Map<String,dynamic>? q]) async {
        final r=await _api.get(path,queryParameters:q);
        final d=r.data;
        if(d is Map) return List.from(d['data']??[]);
        if(d is List) return d;
        return[];
      }
      final rs=await Future.wait([
        get(ApiConstants.roles,{'pagina':1,'limite':50}),
        get(ApiConstants.establishments,{'pagina':1,'limite':50}),
        get(ApiConstants.audit,{'pagina':1,'limite':8}),
        get(ApiConstants.sessions),
        get(ApiConstants.users,{'pagina':1,'limite':100}),
      ]);
      state=DashboardState(data:DashboardData(roles:rs[0],sedes:rs[1],audit:rs[2],sessions:rs[3],users:rs[4]));
    } catch(e){state=DashboardState(error:e.toString());}
  }
}
final dashboardProvider=StateNotifierProvider<DashboardNotifier,DashboardState>(
    (ref)=>DashboardNotifier(ApiClient.instance));
