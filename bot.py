import discord
from discord.ext import commands
import subprocess
import tempfile
import os
import asyncio
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Setup - REMOVE built-in help
intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix='!', intents=intents, help_command=None)

@bot.event
async def on_ready():
    print(f'✅ {bot.user} is online!')
    await bot.change_presence(
        activity=discord.Activity(
            type=discord.ActivityType.playing, 
            name="!info | !obfuscate"
        )
    )

@bot.command(name='obfuscate')
async def obfuscate_cmd(ctx):
    """Obfuscate Lua code from attachment"""
    
    if not ctx.message.attachments:
        embed = discord.Embed(
            title="❌ No File",
            description="Attach .lua file",
            color=discord.Color.red()
        )
        await ctx.send(embed=embed)
        return
    
    file = ctx.message.attachments[0]
    
    if not file.filename.endswith('.lua'):
        embed = discord.Embed(
            title="❌ Wrong File",
            description="Upload .lua only",
            color=discord.Color.red()
        )
        await ctx.send(embed=embed)
        return
    
    try:
        await ctx.defer()
        
        code = await file.read()
        code = code.decode('utf-8')
        
        if len(code) > 1000000:
            embed = discord.Embed(
                title="❌ Too Large",
                description="Max 1MB",
                color=discord.Color.red()
            )
            await ctx.send(embed=embed)
            return
        
        with tempfile.TemporaryDirectory() as tmpdir:
            input_file = os.path.join(tmpdir, 'input.lua')
            output_file = os.path.join(tmpdir, 'output.lua')
            
            with open(input_file, 'w', encoding='utf-8') as f:
                f.write(code)
            
            try:
                result = await asyncio.create_subprocess_exec(
                    'lua',
                    'main_obfuscator.lua',
                    input_file,
                    output_file,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd='/app'
                )
                
                stdout, stderr = await asyncio.wait_for(result.communicate(), timeout=30.0)
                
            except FileNotFoundError:
                result = await asyncio.create_subprocess_exec(
                    'lua',
                    'main_obfuscator.lua',
                    input_file,
                    output_file,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                
                stdout, stderr = await asyncio.wait_for(result.communicate(), timeout=30.0)
            
            if result.returncode != 0:
                error_msg = stderr.decode('utf-8', errors='ignore')[:500]
                embed = discord.Embed(
                    title="❌ Error",
                    description=f"```\n{error_msg}\n```",
                    color=discord.Color.red()
                )
                await ctx.send(embed=embed)
                return
            
            if not os.path.exists(output_file):
                embed = discord.Embed(
                    title="❌ No Output",
                    description="Failed to generate",
                    color=discord.Color.red()
                )
                await ctx.send(embed=embed)
                return
            
            with open(output_file, 'r', encoding='utf-8') as f:
                obfuscated = f.read()
            
            orig_lines = len(code.split('\n'))
            obf_lines = len(obfuscated.split('\n'))
            orig_size = len(code)
            obf_size = len(obfuscated)
            
            await ctx.send(file=discord.File(output_file, filename='obfuscated.lua'))
            
            embed = discord.Embed(
                title="✅ Done!",
                color=discord.Color.green()
            )
            embed.add_field(name="Lines", value=f"{orig_lines} → {obf_lines}", inline=True)
            embed.add_field(name="Size", value=f"{(obf_size/orig_size*100):.1f}%", inline=True)
            embed.add_field(name="Applied", value="Variables, Numbers, Strings, Dead Code", inline=False)
            
            await ctx.send(embed=embed)
    
    except asyncio.TimeoutError:
        embed = discord.Embed(
            title="⏱️ Timeout",
            description="Took too long",
            color=discord.Color.red()
        )
        await ctx.send(embed=embed)
    
    except Exception as e:
        embed = discord.Embed(
            title="❌ Error",
            description=str(e)[:500],
            color=discord.Color.red()
        )
        await ctx.send(embed=embed)

@bot.command(name='info')
async def info_cmd(ctx):
    """Show information and commands"""
    embed = discord.Embed(
        title="🛡️ Lua Obfuscator Bot",
        description="Advanced code obfuscation",
        color=discord.Color.blue()
    )
    embed.add_field(
        name="📖 How to Use",
        value="1. Attach .lua file\n2. Type `!obfuscate`\n3. Download result",
        inline=False
    )
    embed.add_field(
        name="🔒 Features",
        value="✓ Variable renaming\n✓ Number encoding\n✓ String splitting\n✓ Dead code\n✓ Anti-debug",
        inline=False
    )
    embed.add_field(
        name="📋 Commands",
        value="`!obfuscate` - Obfuscate attached file\n`!info` - Show this message\n`!status` - Bot status",
        inline=False
    )
    await ctx.send(embed=embed)

@bot.command(name='status')
async def status_cmd(ctx):
    """Bot status"""
    embed = discord.Embed(
        title="✅ Bot Online",
        color=discord.Color.green()
    )
    embed.add_field(name="Ping", value=f"{bot.latency * 1000:.0f}ms", inline=True)
    embed.add_field(name="Status", value="Ready for obfuscation", inline=True)
    await ctx.send(embed=embed)

@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.CommandNotFound):
        await ctx.send("❌ Unknown command. Type `!info`")
    else:
        await ctx.send(f"❌ Error: {str(error)[:100]}")

# Main
if __name__ == '__main__':
    token = os.environ.get('DISCORD_TOKEN')
    if not token:
        print("❌ ERROR: DISCORD_TOKEN not set!")
        print("Add DISCORD_TOKEN variable in Railway")
        exit(1)
    
    print("🤖 Starting bot...")
    bot.run(token)
