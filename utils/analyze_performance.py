#!/usr/bin/env python3
"""
Sistema de Análise de Performance - IF-UFG
==========================================

Script para análise avançada dos dados de performance coletados
pelo sistema de monitoramento.
"""

import os
import sys
import csv
import json
import sqlite3
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta
import argparse
import warnings

# Suprimir warnings do matplotlib
warnings.filterwarnings('ignore')

class PerformanceAnalyzer:
    def __init__(self, project_dir=None):
        """Inicializar analisador de performance"""
        if project_dir is None:
            # Assumir que está no diretório utils
            self.project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        else:
            self.project_dir = project_dir
            
        self.metrics_dir = os.path.join(self.project_dir, 'logs', 'metrics')
        self.output_dir = os.path.join(self.project_dir, 'logs', 'analysis')
        self.database_path = os.path.join(self.project_dir, 'backend', 'alerting', 'data', 'alerts.db')
        
        # Criar diretório de saída se não existir
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Configurar estilo dos gráficos
        plt.style.use('seaborn-v0_8')
        sns.set_palette("husl")
    
    def load_metrics_data(self, days=7):
        """Carregar dados de métricas dos últimos N dias"""
        print(f"📊 Carregando dados dos últimos {days} dias...")
        
        all_data = []
        
        # Iterar pelos últimos N dias
        for i in range(days):
            date = datetime.now() - timedelta(days=i)
            csv_file = os.path.join(self.metrics_dir, f"recursos_{date.strftime('%Y%m%d')}.csv")
            
            if os.path.exists(csv_file):
                try:
                    # Ler CSV com tratamento de colunas extras
                    df = pd.read_csv(csv_file, on_bad_lines='skip')
                    
                    # Remover colunas vazias
                    df = df.dropna(axis=1, how='all')
                    
                    # Verificar se tem as colunas necessárias
                    required_cols = ['timestamp', 'cpu_percent', 'mem_percent', 'disk_percent']
                    if all(col in df.columns for col in required_cols):
                        # Limpar colunas numéricas
                        for col in ['cpu_percent', 'mem_percent', 'disk_percent']:
                            df[col] = pd.to_numeric(df[col], errors='coerce')
                        
                        # Remover linhas com dados inválidos
                        df = df.dropna(subset=required_cols)
                        df['date'] = date.strftime('%Y-%m-%d')
                        all_data.append(df)
                        print(f"  ✅ {csv_file}: {len(df)} registros")
                    else:
                        print(f"  ⚠️ {csv_file}: colunas ausentes - {df.columns.tolist()}")
                except Exception as e:
                    print(f"  ❌ Erro ao ler {csv_file}: {e}")
        
        if all_data:
            combined_df = pd.concat(all_data, ignore_index=True)
            combined_df['timestamp'] = pd.to_datetime(combined_df['timestamp'])
            print(f"📈 Total de {len(combined_df)} registros carregados")
            return combined_df
        else:
            print("⚠️ Nenhum dado de métrica encontrado")
            return pd.DataFrame()
    
    def load_sensor_data(self, days=7):
        """Carregar dados dos sensores do banco de dados"""
        print(f"🌡️ Carregando dados dos sensores dos últimos {days} dias...")
        
        if not os.path.exists(self.database_path):
            print("❌ Banco de dados não encontrado")
            return pd.DataFrame()
        
        try:
            conn = sqlite3.connect(self.database_path)
            
            # Query para dados dos sensores (tentando sensor_readings primeiro, senão sensor_states)
            query_readings = """
            SELECT esp_id as sensor_id, temperature, humidity, timestamp 
            FROM sensor_readings 
            WHERE timestamp >= datetime('now', '-{} days')
            ORDER BY timestamp ASC
            """.format(days)
            
            query_states = """
            SELECT esp_id as sensor_id, temperature, humidity, last_seen as timestamp 
            FROM sensor_states 
            WHERE last_seen >= datetime('now', '-{} days')
            ORDER BY last_seen ASC
            """.format(days)
            
            # Tentar primeira query, se falhar usar sensor_states
            try:
                df = pd.read_sql_query(query_readings, conn)
                if df.empty:
                    # Se não há dados em sensor_readings, usar sensor_states
                    df = pd.read_sql_query(query_states, conn)
                    print("📊 Usando dados de sensor_states")
                else:
                    print("📊 Usando dados de sensor_readings")
            except:
                # Se tabela sensor_readings não existe, usar sensor_states
                df = pd.read_sql_query(query_states, conn)
                print("📊 Usando dados de sensor_states (fallback)")
            
            conn.close()
            
            if not df.empty:
                df['timestamp'] = pd.to_datetime(df['timestamp'])
                print(f"📊 {len(df)} leituras de sensores carregadas")
            else:
                print("⚠️ Nenhum dado de sensor encontrado")
            
            return df
            
        except Exception as e:
            print(f"❌ Erro ao carregar dados dos sensores: {e}")
            return pd.DataFrame()
    
    def analyze_resource_trends(self, metrics_df):
        """Analisar tendências de recursos"""
        print("📈 Analisando tendências de recursos...")
        
        if metrics_df.empty:
            return {}
        
        analysis = {}
        
        # Estatísticas básicas
        analysis['stats'] = {
            'cpu': {
                'mean': metrics_df['cpu_percent'].mean(),
                'max': metrics_df['cpu_percent'].max(),
                'min': metrics_df['cpu_percent'].min(),
                'std': metrics_df['cpu_percent'].std()
            },
            'memory': {
                'mean': metrics_df['mem_percent'].mean(),
                'max': metrics_df['mem_percent'].max(),
                'min': metrics_df['mem_percent'].min(),
                'std': metrics_df['mem_percent'].std()
            },
            'disk': {
                'mean': metrics_df['disk_percent'].mean(),
                'max': metrics_df['disk_percent'].max(),
                'min': metrics_df['disk_percent'].min(),
                'std': metrics_df['disk_percent'].std()
            }
        }
        
        # Tendências horárias
        metrics_df['hour'] = metrics_df['timestamp'].dt.hour
        hourly_stats = metrics_df.groupby('hour').agg({
            'cpu_percent': ['mean', 'max'],
            'mem_percent': ['mean', 'max'],
            'disk_percent': ['mean', 'max']
        }).round(2)
        
        analysis['hourly_trends'] = hourly_stats.to_dict()
        
        # Detectar picos
        cpu_threshold = analysis['stats']['cpu']['mean'] + 2 * analysis['stats']['cpu']['std']
        mem_threshold = analysis['stats']['memory']['mean'] + 2 * analysis['stats']['memory']['std']
        
        cpu_peaks = metrics_df[metrics_df['cpu_percent'] > cpu_threshold]
        mem_peaks = metrics_df[metrics_df['mem_percent'] > mem_threshold]
        
        analysis['peaks'] = {
            'cpu_peaks': len(cpu_peaks),
            'mem_peaks': len(mem_peaks),
            'cpu_peak_times': cpu_peaks['timestamp'].dt.strftime('%Y-%m-%d %H:%M').tolist(),
            'mem_peak_times': mem_peaks['timestamp'].dt.strftime('%Y-%m-%d %H:%M').tolist()
        }
        
        return analysis
    
    def analyze_sensor_performance(self, sensor_df):
        """Analisar performance dos sensores"""
        print("🌡️ Analisando performance dos sensores...")
        
        if sensor_df.empty:
            return {}
        
        analysis = {}
        
        # Análise por sensor
        for sensor_id in sensor_df['sensor_id'].unique():
            sensor_data = sensor_df[sensor_df['sensor_id'] == sensor_id]
            
            # Calcular gaps nos dados
            sensor_data = sensor_data.sort_values('timestamp')
            time_diffs = sensor_data['timestamp'].diff().dt.total_seconds()
            
            # Considerar gap como > 5 minutos
            gaps = time_diffs[time_diffs > 300].count()
            
            # Estatísticas
            analysis[sensor_id] = {
                'total_readings': len(sensor_data),
                'gaps': int(gaps),
                'uptime_percent': round((1 - gaps / len(sensor_data)) * 100, 2) if len(sensor_data) > 0 else 0,
                'temp_stats': {
                    'mean': sensor_data['temperature'].mean(),
                    'max': sensor_data['temperature'].max(),
                    'min': sensor_data['temperature'].min(),
                    'std': sensor_data['temperature'].std()
                },
                'humidity_stats': {
                    'mean': sensor_data['humidity'].mean(),
                    'max': sensor_data['humidity'].max(),
                    'min': sensor_data['humidity'].min(),
                    'std': sensor_data['humidity'].std()
                }
            }
        
        return analysis
    
    def generate_charts(self, metrics_df, sensor_df):
        """Gerar gráficos de análise"""
        print("📊 Gerando gráficos de análise...")
        
        # Configurar figura com subplots
        fig, axes = plt.subplots(2, 3, figsize=(20, 12))
        fig.suptitle('Análise de Performance - IF-UFG', fontsize=16, y=0.98)
        
        # 1. Tendência de recursos ao longo do tempo
        ax1 = axes[0, 0]
        if not metrics_df.empty:
            ax1.plot(metrics_df['timestamp'], metrics_df['cpu_percent'], label='CPU %', alpha=0.7, marker='o', markersize=4)
            ax1.plot(metrics_df['timestamp'], metrics_df['mem_percent'], label='Memória %', alpha=0.7, marker='s', markersize=4)
            ax1.plot(metrics_df['timestamp'], metrics_df['disk_percent'], label='Disco %', alpha=0.7, marker='^', markersize=4)
            ax1.set_title('Tendência de Recursos')
            ax1.set_xlabel('Tempo')
            ax1.set_ylabel('Porcentagem (%)')
            ax1.legend()
            ax1.grid(True, alpha=0.3)
        else:
            ax1.text(0.5, 0.5, 'Nenhum dado de\nmétricas disponível', 
                    ha='center', va='center', transform=ax1.transAxes, fontsize=12)
            ax1.set_title('Tendência de Recursos')
            ax1.set_xlabel('Tempo')
            ax1.set_ylabel('Porcentagem (%)')
        
        # 2. Distribuição de CPU
        ax2 = axes[0, 1]
        if not metrics_df.empty:
            ax2.hist(metrics_df['cpu_percent'], bins=min(30, len(metrics_df)), alpha=0.7, color='skyblue', edgecolor='black')
            ax2.set_title('Distribuição de Uso de CPU')
            ax2.set_xlabel('CPU (%)')
            ax2.set_ylabel('Frequência')
            ax2.grid(True, alpha=0.3)
        else:
            ax2.text(0.5, 0.5, 'Nenhum dado de\nCPU disponível', 
                    ha='center', va='center', transform=ax2.transAxes, fontsize=12)
            ax2.set_title('Distribuição de Uso de CPU')
            ax2.set_xlabel('CPU (%)')
            ax2.set_ylabel('Frequência')
            ax2.grid(True, alpha=0.3)
        
        # 3. Boxplot de recursos por hora
        if not metrics_df.empty:
            ax3 = axes[0, 2]
            metrics_df['hour'] = metrics_df['timestamp'].dt.hour
            hourly_data = []
            hours = []
            for hour in sorted(metrics_df['hour'].unique()):
                hourly_cpu = metrics_df[metrics_df['hour'] == hour]['cpu_percent']
                if len(hourly_cpu) > 0:
                    hourly_data.append(hourly_cpu)
                    hours.append(f"{hour:02d}h")
            
            if hourly_data:
                ax3.boxplot(hourly_data, labels=hours)
                ax3.set_title('CPU por Hora do Dia')
                ax3.set_xlabel('Hora')
                ax3.set_ylabel('CPU (%)')
                ax3.tick_params(axis='x', rotation=45)
                ax3.grid(True, alpha=0.3)
        
        # 4. Temperatura dos sensores
        if not sensor_df.empty:
            ax4 = axes[1, 0]
            for sensor_id in sensor_df['sensor_id'].unique():
                sensor_data = sensor_df[sensor_df['sensor_id'] == sensor_id]
                ax4.plot(sensor_data['timestamp'], sensor_data['temperature'], 
                        label=f'Sensor {sensor_id}', alpha=0.7)
            ax4.set_title('Temperatura dos Sensores')
            ax4.set_xlabel('Tempo')
            ax4.set_ylabel('Temperatura (°C)')
            ax4.legend()
            ax4.grid(True, alpha=0.3)
        
        # 5. Umidade dos sensores
        if not sensor_df.empty:
            ax5 = axes[1, 1]
            for sensor_id in sensor_df['sensor_id'].unique():
                sensor_data = sensor_df[sensor_df['sensor_id'] == sensor_id]
                ax5.plot(sensor_data['timestamp'], sensor_data['humidity'], 
                        label=f'Sensor {sensor_id}', alpha=0.7)
            ax5.set_title('Umidade dos Sensores')
            ax5.set_xlabel('Tempo')
            ax5.set_ylabel('Umidade (%)')
            ax5.legend()
            ax5.grid(True, alpha=0.3)
        
        # 6. Correlação entre métricas
        ax6 = axes[1, 2]
        if not metrics_df.empty:
            # Selecionar apenas colunas que existem
            corr_cols = []
            for col in ['cpu_percent', 'mem_percent', 'disk_percent']:
                if col in metrics_df.columns:
                    corr_cols.append(col)
            
            if len(corr_cols) >= 2:
                corr_data = metrics_df[corr_cols].corr()
                im = ax6.imshow(corr_data, cmap='coolwarm', aspect='auto', vmin=-1, vmax=1)
                ax6.set_xticks(range(len(corr_cols)))
                ax6.set_yticks(range(len(corr_cols)))
                ax6.set_xticklabels(corr_cols, rotation=45, fontsize=8)
                ax6.set_yticklabels(corr_cols, fontsize=8)
                plt.colorbar(im, ax=ax6, shrink=0.6)
                
                # Adicionar valores na matriz
                for i in range(len(corr_data.columns)):
                    for j in range(len(corr_data.columns)):
                        ax6.text(j, i, f'{corr_data.iloc[i, j]:.2f}', 
                                ha='center', va='center', color='black', fontsize=8)
            else:
                ax6.text(0.5, 0.5, 'Dados insuficientes\npara correlação', 
                        ha='center', va='center', transform=ax6.transAxes, fontsize=12)
        else:
            ax6.text(0.5, 0.5, 'Nenhum dado de\nmétricas disponível', 
                    ha='center', va='center', transform=ax6.transAxes, fontsize=12)
        
        ax6.set_title('Correlação entre Métricas')
        
        plt.tight_layout()
        
        # Salvar gráfico
        chart_file = os.path.join(self.output_dir, f"performance_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png")
        plt.savefig(chart_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"  ✅ Gráficos salvos em: {chart_file}")
        return chart_file
    
    def generate_report(self, resource_analysis, sensor_analysis, chart_file):
        """Gerar relatório completo"""
        print("📄 Gerando relatório de análise...")
        
        report_file = os.path.join(self.output_dir, f"performance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.html")
        
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Relatório de Performance - IF-UFG</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }}
        .section {{ margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 8px; }}
        .metric {{ display: inline-block; margin: 10px; padding: 15px; background: #f8f9fa; border-radius: 5px; min-width: 150px; text-align: center; }}
        .metric-value {{ font-size: 24px; font-weight: bold; color: #2c3e50; }}
        .metric-label {{ color: #7f8c8d; font-size: 14px; }}
        .alert {{ background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 10px; border-radius: 5px; margin: 10px 0; }}
        .ok {{ background: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 10px; border-radius: 5px; margin: 10px 0; }}
        table {{ width: 100%; border-collapse: collapse; margin: 10px 0; }}
        th, td {{ padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }}
        th {{ background-color: #f2f2f2; }}
        .chart {{ text-align: center; margin: 20px 0; }}
        .chart img {{ max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 8px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Relatório de Performance - IF-UFG</h1>
            <p><strong>Data:</strong> {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}</p>
            <p><strong>Servidor:</strong> {os.uname().nodename}</p>
        </div>
        
        <div class="section">
            <h2>📈 Resumo de Recursos</h2>
"""
        
        # Adicionar métricas de recursos
        if resource_analysis:
            stats = resource_analysis.get('stats', {})
            html_content += '<div style="display: flex; flex-wrap: wrap; justify-content: space-around;">'
            
            for resource, data in stats.items():
                html_content += f"""
                <div class="metric">
                    <div class="metric-value">{data.get('mean', 0):.1f}%</div>
                    <div class="metric-label">{resource.upper()} Médio</div>
                </div>
                <div class="metric">
                    <div class="metric-value">{data.get('max', 0):.1f}%</div>
                    <div class="metric-label">{resource.upper()} Máximo</div>
                </div>
                """
            
            html_content += '</div>'
            
            # Alertas de picos
            peaks = resource_analysis.get('peaks', {})
            if peaks.get('cpu_peaks', 0) > 0 or peaks.get('mem_peaks', 0) > 0:
                html_content += f"""
                <div class="alert">
                    <strong>⚠️ Picos Detectados:</strong><br>
                    • CPU: {peaks.get('cpu_peaks', 0)} picos<br>
                    • Memória: {peaks.get('mem_peaks', 0)} picos
                </div>
                """
            else:
                html_content += '<div class="ok"><strong>✅ Nenhum pico anômalo detectado</strong></div>'
        
        html_content += '</div>'
        
        # Adicionar métricas de sensores
        html_content += """
        <div class="section">
            <h2>🌡️ Performance dos Sensores</h2>
            <table>
                <tr>
                    <th>Sensor</th>
                    <th>Leituras</th>
                    <th>Uptime</th>
                    <th>Temp. Média</th>
                    <th>Umid. Média</th>
                    <th>Gaps</th>
                </tr>
        """
        
        for sensor_id, data in sensor_analysis.items():
            uptime_class = "ok" if data['uptime_percent'] > 95 else "alert"
            html_content += f"""
                <tr>
                    <td>Sensor {sensor_id}</td>
                    <td>{data['total_readings']}</td>
                    <td><span class="{uptime_class}">{data['uptime_percent']}%</span></td>
                    <td>{data['temp_stats']['mean']:.1f}°C</td>
                    <td>{data['humidity_stats']['mean']:.1f}%</td>
                    <td>{data['gaps']}</td>
                </tr>
            """
        
        html_content += """
            </table>
        </div>
        """
        
        # Adicionar gráficos
        if chart_file and os.path.exists(chart_file):
            chart_name = os.path.basename(chart_file)
            html_content += f"""
            <div class="section">
                <h2>📊 Gráficos de Análise</h2>
                <div class="chart">
                    <img src="{chart_name}" alt="Gráficos de Performance">
                </div>
            </div>
            """
        
        # Adicionar recomendações
        html_content += """
        <div class="section">
            <h2>💡 Recomendações</h2>
            <ul>
                <li><strong>Monitoramento:</strong> Continue monitorando regularmente os recursos do sistema</li>
                <li><strong>Alertas:</strong> Configure alertas automáticos para valores críticos</li>
                <li><strong>Backup:</strong> Mantenha backups regulares dos dados</li>
                <li><strong>Manutenção:</strong> Realize manutenção preventiva nos sensores</li>
                <li><strong>Otimização:</strong> Considere otimizar processos que consomem muitos recursos</li>
            </ul>
        </div>
        
        <div style="text-align: center; margin-top: 30px; color: #7f8c8d; font-size: 14px;">
            <p><em>Relatório gerado automaticamente pelo Sistema de Monitoramento IF-UFG</em></p>
        </div>
    </div>
</body>
</html>
        """
        
        # Salvar relatório
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"  ✅ Relatório salvo em: {report_file}")
        return report_file
    
    def run_analysis(self, days=7):
        """Executar análise completa"""
        print("🚀 Iniciando análise de performance...")
        print("=" * 50)
        
        # Carregar dados
        metrics_df = self.load_metrics_data(days)
        sensor_df = self.load_sensor_data(days)
        
        # Análises
        resource_analysis = self.analyze_resource_trends(metrics_df)
        sensor_analysis = self.analyze_sensor_performance(sensor_df)
        
        # Gerar gráficos
        chart_file = self.generate_charts(metrics_df, sensor_df)
        
        # Gerar relatório
        report_file = self.generate_report(resource_analysis, sensor_analysis, chart_file)
        
        print("=" * 50)
        print("✅ Análise concluída!")
        print(f"📄 Relatório: {report_file}")
        print(f"📊 Gráficos: {chart_file}")
        
        return {
            'report_file': report_file,
            'chart_file': chart_file,
            'resource_analysis': resource_analysis,
            'sensor_analysis': sensor_analysis
        }

def main():
    """Função principal"""
    parser = argparse.ArgumentParser(description='Análise de Performance IF-UFG')
    parser.add_argument('--days', type=int, default=7, help='Número de dias para análise (padrão: 7)')
    parser.add_argument('--project-dir', type=str, help='Diretório do projeto')
    
    args = parser.parse_args()
    
    try:
        analyzer = PerformanceAnalyzer(args.project_dir)
        result = analyzer.run_analysis(args.days)
        
        # Exibir resumo
        if result['resource_analysis']:
            stats = result['resource_analysis'].get('stats', {})
            print("\n📊 Resumo:")
            for resource, data in stats.items():
                print(f"  {resource.upper()}: Média {data.get('mean', 0):.1f}%, Máximo {data.get('max', 0):.1f}%")
        
        return 0
        
    except KeyboardInterrupt:
        print("\n⚠️ Análise interrompida pelo usuário")
        return 1
    except Exception as e:
        print(f"❌ Erro durante análise: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main()) 