const fs = require('fs');
const https = require('https');

// Extract API key from Dart config file
function getGeminiApiKey() {
  try {
    const configFile = fs.readFileSync('lib/config/api_config.dart', 'utf8');
    const geminiKeyMatch = configFile.match(/static const String geminiApiKey = '([^']+)'/);
    
    if (geminiKeyMatch) {
      return geminiKeyMatch[1];
    }
    return null;
  } catch (error) {
    console.error('❌ Error reading config file:', error.message);
    return null;
  }
}

// Test Gemini API with a simple request
async function testGeminiAPI() {
  console.log('🧪 Testing Gemini API Integration...');
  console.log('');
  
  const apiKey = getGeminiApiKey();
  
  if (!apiKey) {
    console.log('❌ Could not extract API key from config file');
    return;
  }
  
  if (apiKey === 'YOUR_GEMINI_API_KEY') {
    console.log('❌ API key is still placeholder - please add your actual Gemini API key');
    console.log('📁 File: lib/config/api_config.dart');
    console.log('📍 Line 3: Replace YOUR_GEMINI_API_KEY with your actual key');
    return;
  }
  
  console.log('🔍 API Key Status:');
  console.log('   Format: ' + apiKey.substring(0, 10) + '...' + apiKey.substring(apiKey.length - 4));
  console.log('   Length: ' + apiKey.length + ' characters');
  console.log('   Valid format: ' + (apiKey.startsWith('AIza') ? '✅' : '⚠️'));
  console.log('');
  
  // Test API call
  console.log('📡 Testing API call to Gemini...');
  
  const testPrompt = 'I need help fixing my kitchen sink that is leaking. What type of service professional should I contact?';
  
  const requestData = JSON.stringify({
    contents: [{
      parts: [{
        text: testPrompt
      }]
    }],
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 150
    }
  });
  
  const options = {
    hostname: 'generativelanguage.googleapis.com',
    port: 443,
    path: `/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(requestData)
    }
  };
  
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        console.log('📊 API Response Status:', res.statusCode);
        
        if (res.statusCode === 200) {
          try {
            const response = JSON.parse(data);
            
            if (response.candidates && response.candidates[0] && response.candidates[0].content) {
              const aiResponse = response.candidates[0].content.parts[0].text;
              console.log('✅ Gemini API is working!');
              console.log('');
              console.log('🤖 Test Question: ' + testPrompt);
              console.log('');
              console.log('💬 Gemini Response:');
              console.log(aiResponse);
              console.log('');
              console.log('🎯 API Integration Status: WORKING ✅');
            } else {
              console.log('⚠️ API responded but with unexpected format');
              console.log('📄 Response:', data.substring(0, 200) + '...');
            }
          } catch (parseError) {
            console.log('❌ Error parsing API response:', parseError.message);
            console.log('📄 Raw response:', data.substring(0, 200) + '...');
          }
        } else {
          console.log('❌ API call failed');
          console.log('📄 Error response:', data);
          
          if (res.statusCode === 400) {
            console.log('💡 Possible issues:');
            console.log('   - Invalid API key format');
            console.log('   - API key not enabled for Gemini');
            console.log('   - Request format incorrect');
          } else if (res.statusCode === 403) {
            console.log('💡 Possible issues:');
            console.log('   - API key not authorized');
            console.log('   - Gemini API not enabled in Google Cloud Console');
            console.log('   - Billing not set up');
          }
        }
        
        resolve();
      });
    });
    
    req.on('error', (error) => {
      console.log('❌ Network error:', error.message);
      reject(error);
    });
    
    req.write(requestData);
    req.end();
  });
}

// Run the test
testGeminiAPI().then(() => {
  console.log('');
  console.log('🧪 Gemini API test completed!');
  console.log('');
  console.log('💡 If API is working:');
  console.log('   - AI Task Intake should provide intelligent responses');
  console.log('   - Service categorization should be more accurate');
  console.log('   - User conversations should be more natural');
  console.log('');
  console.log('💡 If API failed:');
  console.log('   - Check API key is correct');
  console.log('   - Verify Gemini API is enabled in Google Cloud Console');
  console.log('   - Ensure billing is set up');
  
  process.exit(0);
}).catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});

