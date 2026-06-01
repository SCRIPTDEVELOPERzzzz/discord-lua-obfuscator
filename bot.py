import discord
from discord.ext import commands
import subprocess
import tempfile
import os
import asyncio
from dotenv import load_dotenv

load_dotenv()

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix='!', intents=intents)

@bot.event
async def on_ready():
    print(f'✅ {bot.user} is online!')
    await bot.change_presence(
        activity=discord.Activity(
            type=discord.ActivityType.playing, 
            name="!obfuscate | !help"
        )
    )

@bot.command(name='obfuscate')
async def obfuscate_cmd(ctx):
    """Obfuscate Lua code from attachment"""
    
    if not ctx.message.attachments:
        embed = discord.Embed(
            title="❌ No File Provided",
            description="Attach .lua file to obfuscate",
            color=discord.Color.red()
        )
        await ctx.send(embed=embed)
        return
    
    file = ctx.message.attachments[0]
    
    if not file.filename.endswith('.lua'):
        embed = discord.Embed(
            title="❌ Wrong File",
            description="Upload .lua file only!",
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
                    description=f"```{error_msg}```",
                    color=discord.Color.red()
                )
                await ctx.send(embed=embed)
                return
            
            if not os.path.exists(output_file):
                embed = discord.Embed(
                    title="❌ Output Error",
                    description="No output generated",
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
            
            await ctx.send(embed=embed)
    
    except asyncio.TimeoutError:
        embed = discord.Embed(
            title="⏱️ Timeout",
            description="Too long (max 30s)",
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

@bot.command(name='help')
async def help_cmd(ctx):
    """Show help"""
    embed = discord.Embed(
        title="🛡️ Lua Obfuscator",
        description="Obfuscate Lua code",
        color=discord.Color.blue()
    )
    embed.add_field(
        name="How to use",
        value="1. Attach .lua file\n2. Type !obfuscate\n3. Download result",
        inline=False
    )
    await ctx.send(embed=embed)

token = os.environ.get('DISCORD_TOKEN')
if not token:
    print("ERROR: DISCORD_TOKEN not set!")
    exit(1)

bot.run(token)
