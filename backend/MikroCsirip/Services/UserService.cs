using Microsoft.EntityFrameworkCore;
using MikroCsirip.Data;
using MikroCsirip.DTOs;
using MikroCsirip.Models;

namespace MikroCsirip.Services;

public interface IUserService
{
 Task<UserDto?> GetByUsernameAsync(string username, int? currentUserId);
 Task<UserDto?> UpdateProfileAsync(int userId, UpdateProfileRequest request);
 Task<bool> FollowAsync(int followerId, int followingId);
 Task<List<UserDto>> SearchAsync(string query);
}

public class UserService : IUserService
{
 private readonly AppDbContext _db;

 public UserService(AppDbContext db) => _db = db;

 public async Task<UserDto?> GetByUsernameAsync(string username, int? currentUserId)
 {
 var user = await _db.Users
 .Include(u => u.Posts)
 .Include(u => u.Followers)
 .Include(u => u.Following)
 .FirstOrDefaultAsync(u => u.Username == username);

 return user == null ? null : MapUser(user);
 }

 public async Task<UserDto?> UpdateProfileAsync(int userId, UpdateProfileRequest request)
 {
 var user = await _db.Users
 .Include(u => u.Posts)
 .Include(u => u.Followers)
 .Include(u => u.Following)
 .FirstOrDefaultAsync(u => u.Id == userId);

 if (user == null) return null;

 if (request.Bio != null) user.Bio = request.Bio;
 if (request.AvatarUrl != null) user.AvatarUrl = request.AvatarUrl;

 await _db.SaveChangesAsync();
 return MapUser(user);
 }

 public async Task<bool> FollowAsync(int followerId, int followingId)
 {
 if (followerId == followingId) return false;

 var existing = await _db.Follows.FindAsync(followerId, followingId);
 if (existing != null)
 {
 _db.Follows.Remove(existing);
 await _db.SaveChangesAsync();
 return false;
 }

 _db.Follows.Add(new Follow { FollowerId = followerId, FollowingId = followingId });
 await _db.SaveChangesAsync();
 return true;
 }

 public async Task<List<UserDto>> SearchAsync(string query)
 {
 return await _db.Users
 .Include(u => u.Posts)
 .Include(u => u.Followers)
 .Include(u => u.Following)
 .Where(u => u.Username.Contains(query) || (u.Bio != null && u.Bio.Contains(query)))
 .Take(20)
 .Select(u => MapUser(u))
 .ToListAsync();
 }

 private static UserDto MapUser(User u) =>
 new(u.Id, u.Username, u.Email, u.Bio, u.AvatarUrl, u.CreatedAt,
 u.Posts.Count, u.Followers.Count, u.Following.Count);
}
