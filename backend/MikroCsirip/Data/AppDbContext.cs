using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;
using MikroCsirip.Models;

namespace MikroCsirip.Data;

public class AppDbContext : DbContext
{
 private const string Collation = "Hungarian_CI_AS";

 public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

 public DbSet<User> Users => Set<User>();
 public DbSet<Post> Posts => Set<Post>();
 public DbSet<Follow> Follows => Set<Follow>();
 public DbSet<Like> Likes => Set<Like>();

 protected override void OnModelCreating(ModelBuilder modelBuilder)
 {
 modelBuilder.UseCollation(Collation);

 modelBuilder.Entity<User>(e =>
 {
 e.Property(u => u.Username).HasMaxLength(50).UseCollation(Collation);
 e.Property(u => u.Email).HasMaxLength(100).UseCollation(Collation);
 e.Property(u => u.Bio).HasMaxLength(160).UseCollation(Collation);
 e.Property(u => u.AvatarUrl).HasMaxLength(500).UseCollation(Collation);
 e.Property(u => u.PasswordHash).HasMaxLength(256);
 e.HasIndex(u => u.Email).IsUnique();
 e.HasIndex(u => u.Username).IsUnique();
 });

 modelBuilder.Entity<Post>(e =>
 {
 e.Property(p => p.Content).HasMaxLength(280).UseCollation(Collation);
 e.HasOne(p => p.User)
 .WithMany(u => u.Posts)
 .HasForeignKey(p => p.UserId)
 .OnDelete(DeleteBehavior.Cascade);
 });

 modelBuilder.Entity<Follow>(e =>
 {
 e.HasKey(f => new { f.FollowerId, f.FollowingId });
 e.HasOne(f => f.Follower)
 .WithMany(u => u.Following)
 .HasForeignKey(f => f.FollowerId)
 .OnDelete(DeleteBehavior.Restrict);
 e.HasOne(f => f.Following)
 .WithMany(u => u.Followers)
 .HasForeignKey(f => f.FollowingId)
 .OnDelete(DeleteBehavior.Restrict);
 });

 modelBuilder.Entity<Like>(e =>
 {
 e.HasKey(l => new { l.UserId, l.PostId });
 e.HasOne(l => l.User)
 .WithMany(u => u.Likes)
 .HasForeignKey(l => l.UserId)
 .OnDelete(DeleteBehavior.Restrict);
 e.HasOne(l => l.Post)
 .WithMany(p => p.Likes)
 .HasForeignKey(l => l.PostId)
 .OnDelete(DeleteBehavior.Cascade);
 });
 }
}

public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
 public AppDbContext CreateDbContext(string[] args)
 {
 var config = new ConfigurationBuilder()
 .SetBasePath(Directory.GetCurrentDirectory())
 .AddJsonFile("appsettings.json")
 .AddJsonFile("appsettings.Development.json", optional: true)
 .Build();

 var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
 optionsBuilder.UseSqlServer(config.GetConnectionString("DefaultConnection"));

 return new AppDbContext(optionsBuilder.Options);
 }
}
