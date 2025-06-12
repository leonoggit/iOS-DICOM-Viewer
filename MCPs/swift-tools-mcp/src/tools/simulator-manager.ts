import { execSync } from 'child_process';

export interface SimulatorDevice {
  udid: string;
  name: string;
  state: 'Booted' | 'Shutdown' | 'Booting' | 'Shutting Down';
  runtime: string;
  deviceType: string;
  availability: string;
}

export interface SimulatorRuntime {
  identifier: string;
  name: string;
  version: string;
  isAvailable: boolean;
}

export class SimulatorManager {
  async listSimulators(runtime?: string, deviceType?: string): Promise<any> {
    try {
      const output = execSync('xcrun simctl list devices --json', { encoding: 'utf8' });
      const data = JSON.parse(output);
      
      const simulators: SimulatorDevice[] = [];
      
      for (const [runtimeKey, devices] of Object.entries(data.devices)) {
        if (runtime && !runtimeKey.includes(runtime)) continue;
        
        for (const device of devices as any[]) {
          if (deviceType && !device.name.toLowerCase().includes(deviceType.toLowerCase())) continue;
          
          simulators.push({
            udid: device.udid,
            name: device.name,
            state: device.state,
            runtime: runtimeKey,
            deviceType: device.deviceTypeIdentifier || 'Unknown',
            availability: device.isAvailable ? 'Available' : 'Unavailable'
          });
        }
      }

      return {
        content: [{
          type: 'text',
          text: this.formatSimulatorList(simulators),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to list iOS simulators: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async bootSimulator(deviceId: string, waitForBoot: boolean = true): Promise<any> {
    try {
      // First check if simulator is already booted
      const device = await this.getDeviceInfo(deviceId);
      if (!device) {
        throw new Error(`Simulator with ID/name '${deviceId}' not found`);
      }

      if (device.state === 'Booted') {
        return {
          content: [{
            type: 'text',
            text: `✅ Simulator '${device.name}' is already booted and ready!`,
          }],
        };
      }

      // Boot the simulator
      execSync(`xcrun simctl boot "${device.udid}"`, { encoding: 'utf8' });
      
      let bootMessage = `🚀 Simulator '${device.name}' boot initiated`;
      
      if (waitForBoot) {
        // Wait for simulator to boot
        let attempts = 0;
        const maxAttempts = 30; // 30 seconds timeout
        
        while (attempts < maxAttempts) {
          const currentDevice = await this.getDeviceInfo(deviceId);
          if (currentDevice && currentDevice.state === 'Booted') {
            bootMessage += `\n✅ Simulator is now booted and ready!`;
            break;
          }
          
          await this.sleep(1000); // Wait 1 second
          attempts++;
        }
        
        if (attempts >= maxAttempts) {
          bootMessage += `\n⚠️ Simulator boot timeout - check manually`;
        }
      }

      return {
        content: [{
          type: 'text',
          text: bootMessage,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to boot simulator: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async installApp(appPath: string, deviceId: string, launch: boolean = true): Promise<any> {
    try {
      const device = await this.getDeviceInfo(deviceId);
      if (!device) {
        throw new Error(`Simulator with ID/name '${deviceId}' not found`);
      }

      if (device.state !== 'Booted') {
        throw new Error(`Simulator '${device.name}' must be booted before installing apps`);
      }

      // Install the app
      execSync(`xcrun simctl install "${device.udid}" "${appPath}"`, { encoding: 'utf8' });
      
      let result = `✅ App installed successfully on '${device.name}'`;

      if (launch) {
        try {
          // Extract bundle identifier from app
          const bundleId = await this.getBundleIdentifier(appPath);
          
          // Launch the app
          execSync(`xcrun simctl launch "${device.udid}" "${bundleId}"`, { encoding: 'utf8' });
          result += `\n🚀 App launched successfully!`;
        } catch (launchError) {
          result += `\n⚠️ App installed but failed to launch: ${launchError}`;
        }
      }

      return {
        content: [{
          type: 'text',
          text: result,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to install app: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async shutdownSimulator(deviceId: string): Promise<any> {
    try {
      const device = await this.getDeviceInfo(deviceId);
      if (!device) {
        throw new Error(`Simulator with ID/name '${deviceId}' not found`);
      }

      if (device.state === 'Shutdown') {
        return {
          content: [{
            type: 'text',
            text: `ℹ️ Simulator '${device.name}' is already shut down`,
          }],
        };
      }

      execSync(`xcrun simctl shutdown "${device.udid}"`, { encoding: 'utf8' });

      return {
        content: [{
          type: 'text',
          text: `🛑 Simulator '${device.name}' has been shut down`,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to shutdown simulator: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async openSimulatorApp(): Promise<any> {
    try {
      execSync('open -a Simulator', { encoding: 'utf8' });
      
      return {
        content: [{
          type: 'text',
          text: `📱 Simulator app opened`,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to open Simulator app: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async getSimulatorLogs(deviceId: string, appBundleId?: string): Promise<any> {
    try {
      const device = await this.getDeviceInfo(deviceId);
      if (!device) {
        throw new Error(`Simulator with ID/name '${deviceId}' not found`);
      }

      let logCmd = `xcrun simctl spawn "${device.udid}" log stream`;
      if (appBundleId) {
        logCmd += ` --predicate 'process == "${appBundleId}"'`;
      }
      logCmd += ' --level debug --style compact';

      return {
        content: [{
          type: 'text',
          text: `📋 To view logs for simulator '${device.name}', run:\n\n\`${logCmd}\`\n\nNote: This will stream live logs. Press Ctrl+C to stop.`,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to get simulator logs: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async resetSimulator(deviceId: string): Promise<any> {
    try {
      const device = await this.getDeviceInfo(deviceId);
      if (!device) {
        throw new Error(`Simulator with ID/name '${deviceId}' not found`);
      }

      // Shutdown first if booted
      if (device.state === 'Booted') {
        execSync(`xcrun simctl shutdown "${device.udid}"`, { encoding: 'utf8' });
      }

      // Erase all content and settings
      execSync(`xcrun simctl erase "${device.udid}"`, { encoding: 'utf8' });

      return {
        content: [{
          type: 'text',
          text: `🔄 Simulator '${device.name}' has been reset to factory settings`,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to reset simulator: ${error}`,
        }],
        isError: true,
      };
    }
  }

  private async getDeviceInfo(deviceId: string): Promise<SimulatorDevice | null> {
    try {
      const output = execSync('xcrun simctl list devices --json', { encoding: 'utf8' });
      const data = JSON.parse(output);
      
      for (const [runtimeKey, devices] of Object.entries(data.devices)) {
        for (const device of devices as any[]) {
          if (device.udid === deviceId || device.name === deviceId) {
            return {
              udid: device.udid,
              name: device.name,
              state: device.state,
              runtime: runtimeKey,
              deviceType: device.deviceTypeIdentifier || 'Unknown',
              availability: device.isAvailable ? 'Available' : 'Unavailable'
            };
          }
        }
      }
      
      return null;
    } catch (error) {
      return null;
    }
  }

  private async getBundleIdentifier(appPath: string): Promise<string> {
    try {
      const output = execSync(`/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "${appPath}/Info.plist"`, { encoding: 'utf8' });
      return output.trim();
    } catch (error) {
      throw new Error(`Failed to get bundle identifier from ${appPath}`);
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  private formatSimulatorList(simulators: SimulatorDevice[]): string {
    let output = `# iOS Simulators\n\n`;
    
    if (simulators.length === 0) {
      output += `No simulators found.\n\n`;
      return output;
    }

    // Group by runtime
    const groupedByRuntime = simulators.reduce((groups, sim) => {
      const runtime = sim.runtime;
      if (!groups[runtime]) {
        groups[runtime] = [];
      }
      groups[runtime].push(sim);
      return groups;
    }, {} as Record<string, SimulatorDevice[]>);

    const totalSimulators = simulators.length;
    const bootedSimulators = simulators.filter(s => s.state === 'Booted').length;
    
    output += `**Total Simulators:** ${totalSimulators}\n`;
    output += `**Currently Booted:** ${bootedSimulators}\n\n`;

    for (const [runtime, devices] of Object.entries(groupedByRuntime)) {
      const runtimeName = runtime.replace('com.apple.CoreSimulator.SimRuntime.', '').replace(/-/g, ' ');
      output += `## ${runtimeName}\n\n`;
      
      for (const device of devices) {
        const stateIcon = this.getStateIcon(device.state);
        const availIcon = device.availability === 'Available' ? '✅' : '❌';
        
        output += `${stateIcon} **${device.name}**\n`;
        output += `   📱 UDID: \`${device.udid}\`\n`;
        output += `   🔄 State: ${device.state}\n`;
        output += `   ${availIcon} Availability: ${device.availability}\n\n`;
      }
    }

    // Add helpful commands
    output += `## Useful Commands\n\n`;
    output += `### Boot a simulator:\n`;
    output += `\`xcrun simctl boot "Device Name"\` or \`xcrun simctl boot UDID\`\n\n`;
    
    output += `### Install app:\n`;
    output += `\`xcrun simctl install "Device Name" /path/to/App.app\`\n\n`;
    
    output += `### Launch app:\n`;
    output += `\`xcrun simctl launch "Device Name" com.yourcompany.bundleid\`\n\n`;
    
    output += `### View logs:\n`;
    output += `\`xcrun simctl spawn "Device Name" log stream --level debug\`\n\n`;
    
    output += `### Reset simulator:\n`;
    output += `\`xcrun simctl erase "Device Name"\`\n\n`;

    return output;
  }

  private getStateIcon(state: string): string {
    switch (state) {
      case 'Booted':
        return '🟢';
      case 'Shutdown':
        return '⚪';
      case 'Booting':
        return '🟡';
      case 'Shutting Down':
        return '🟠';
      default:
        return '❓';
    }
  }
}