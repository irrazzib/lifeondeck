using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LifeOnDeck.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddServerUpdatedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SideboardDecks_UserId_UpdatedAt",
                table: "SideboardDecks");

            migrationBuilder.DropIndex(
                name: "IX_GameRecords_UserId_UpdatedAt",
                table: "GameRecords");

            migrationBuilder.AddColumn<DateTime>(
                name: "ServerUpdatedAt",
                table: "SideboardDecks",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "ServerUpdatedAt",
                table: "GameRecords",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "ServerUpdatedAt",
                table: "AppSettings",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            // Backfill: seed the new server-side cursor from the existing client
            // UpdatedAt so pre-migration rows remain pullable instead of pinning to
            // DateTime.MinValue.
            migrationBuilder.Sql(
                "UPDATE \"GameRecords\" SET \"ServerUpdatedAt\" = \"UpdatedAt\";");
            migrationBuilder.Sql(
                "UPDATE \"SideboardDecks\" SET \"ServerUpdatedAt\" = \"UpdatedAt\";");
            migrationBuilder.Sql(
                "UPDATE \"AppSettings\" SET \"ServerUpdatedAt\" = \"UpdatedAt\";");

            migrationBuilder.CreateIndex(
                name: "IX_SideboardDecks_UserId_ServerUpdatedAt",
                table: "SideboardDecks",
                columns: new[] { "UserId", "ServerUpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_GameRecords_UserId_ServerUpdatedAt",
                table: "GameRecords",
                columns: new[] { "UserId", "ServerUpdatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SideboardDecks_UserId_ServerUpdatedAt",
                table: "SideboardDecks");

            migrationBuilder.DropIndex(
                name: "IX_GameRecords_UserId_ServerUpdatedAt",
                table: "GameRecords");

            migrationBuilder.DropColumn(
                name: "ServerUpdatedAt",
                table: "SideboardDecks");

            migrationBuilder.DropColumn(
                name: "ServerUpdatedAt",
                table: "GameRecords");

            migrationBuilder.DropColumn(
                name: "ServerUpdatedAt",
                table: "AppSettings");

            migrationBuilder.CreateIndex(
                name: "IX_SideboardDecks_UserId_UpdatedAt",
                table: "SideboardDecks",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_GameRecords_UserId_UpdatedAt",
                table: "GameRecords",
                columns: new[] { "UserId", "UpdatedAt" });
        }
    }
}
