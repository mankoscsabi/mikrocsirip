import { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
 { path: '', redirectTo: 'feed', pathMatch: 'full' },
 {
 path: 'feed',
 loadComponent: () => import('./features/feed/feed.component').then(m => m.FeedComponent),
 canActivate: [authGuard]
 },
 {
 path: 'login',
 loadComponent: () => import('./features/auth/login.component').then(m => m.LoginComponent)
 },
 {
 path: 'register',
 loadComponent: () => import('./features/auth/register.component').then(m => m.RegisterComponent)
 },
 {
 path: 'profile/:username',
 loadComponent: () => import('./features/profile/profile.component').then(m => m.ProfileComponent)
 },
 { path: '**', redirectTo: 'feed' }
];
