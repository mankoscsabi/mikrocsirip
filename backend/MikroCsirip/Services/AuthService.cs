using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using MikroCsirip.Data;
using MikroCsirip.DTOs;
using MikroCsirip.Models;

namespace MikroCsirip.Services;

public interface IAuthService
{
 Task<AuthResponse?> RegisterAsync(RegisterRequest request);
 Task<AuthResponse?> LoginAsync(LoginRequest request);
}

public class AuthService : IAuthService
{
 private readonly AppDbContext _db;
 private readonly IConfiguration _config;

 public AuthService(AppDbContext db, IConfiguration config)
 {
 _db = db;
 _config = config;
 }

 public async Task<AuthResponse?> RegisterAsync(RegisterRequest request)
 {
 if (await _db.Users.AnyAsync(u => u.Email == request.Email || u.Username == request.Username))
 return null;

 var user = new User
 {
 Username = request.Username,
 Email = request.Email,
 PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password)
 };

 _db.Users.Add(user);
 await _db.SaveChangesAsync();

 return new AuthResponse(GenerateToken(user), MapUser(user, 0, 0, 0));
 }

 public async Task<AuthResponse?> LoginAsync(LoginRequest request)
 {
 var user = await _db.Users
 .Include(u => u.Posts)
 .Include(u => u.Followers)
 .Include(u => u.Following)
 .FirstOrDefaultAsync(u => u.Email == request.Email);

 if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
 return null;

 return new AuthResponse(
 GenerateToken(user),
 MapUser(user, user.Posts.Count, user.Followers.Count, user.Following.Count)
 );
 }

 private string GenerateToken(User user)
 {
 var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]!));
 var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

 var claims = new[]
 {
 new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
 new Claim(ClaimTypes.Name, user.Username),
 new Claim(ClaimTypes.Email, user.Email)
 };

 var token = new JwtSecurityToken(
 issuer: _config["Jwt:Issuer"],
 audience: _config["Jwt:Audience"],
 claims: claims,
 expires: DateTime.UtcNow.AddDays(7),
 signingCredentials: creds
 );

 return new JwtSecurityTokenHandler().WriteToken(token);
 }

 private static UserDto MapUser(User u, int posts, int followers, int following) =>
 new(u.Id, u.Username, u.Email, u.Bio, u.AvatarUrl, u.CreatedAt, posts, followers, following);
}
