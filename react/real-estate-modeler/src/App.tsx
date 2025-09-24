import { useState, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, BarChart, Bar, Cell, ReferenceLine } from 'recharts';
import { Plus, Trash2, TrendingUp, TrendingDown, DollarSign, Home } from 'lucide-react';

const RealEstateAnalyzer = () => {
  const [personalIncome, setPersonalIncome] = useState(100000);
  const [annualIncomeGrowth, setAnnualIncomeGrowth] = useState(3);
  const [annualRentGrowth, setAnnualRentGrowth] = useState(2.5);
  const [properties, setProperties] = useState([
    {
      id: 1,
      name: "Main Street Duplex",
      purchasePrice: 300000,
      downPayment: 60000,
      interestRate: 6.5,
      loanTerm: 30,
      monthlyRent: 2500,
      monthlyExpenses: 500,
      propertyTax: 3600,
      insurance: 1200
    }
  ]);

  const addProperty = () => {
    const newProperty = {
      id: Date.now(),
      name: `Property ${properties.length + 1}`,
      purchasePrice: 300000,
      downPayment: 60000,
      interestRate: 6.5,
      loanTerm: 30,
      monthlyRent: 2500,
      monthlyExpenses: 500,
      propertyTax: 3600,
      insurance: 1200
    };
    setProperties([...properties, newProperty]);
  };

  const removeProperty = (id) => {
    setProperties(properties.filter(prop => prop.id !== id));
  };

  const updateProperty = (id, field, value) => {
    setProperties(properties.map(prop => 
      prop.id === id ? { 
        ...prop, 
        [field]: field === 'name' ? value : (parseFloat(value) || 0)
      } : prop
    ));
  };

  const calculateMonthlyPayment = (principal, rate, term) => {
    const monthlyRate = rate / 100 / 12;
    const numPayments = term * 12;
    return (principal * monthlyRate * Math.pow(1 + monthlyRate, numPayments)) / 
           (Math.pow(1 + monthlyRate, numPayments) - 1);
  };

  const portfolioMetrics = useMemo(() => {
    let totalMonthlyDebt = 0;
    let totalMonthlyCashFlow = 0;
    let totalDownPayments = 0;
    let totalPropertyValue = 0;
    
    const propertyDetails = properties.map((prop, index) => {
      const loanAmount = prop.purchasePrice - prop.downPayment;
      const monthlyPayment = calculateMonthlyPayment(loanAmount, prop.interestRate, prop.loanTerm);
      const monthlyTaxInsurance = (prop.propertyTax + prop.insurance) / 12;
      const totalMonthlyExpenses = monthlyPayment + monthlyTaxInsurance + prop.monthlyExpenses;
      const monthlyCashFlow = prop.monthlyRent - totalMonthlyExpenses;
      
      totalMonthlyDebt += monthlyPayment;
      totalMonthlyCashFlow += monthlyCashFlow;
      totalDownPayments += prop.downPayment;
      totalPropertyValue += prop.purchasePrice;
      
      return {
        property: `${index + 1}: ${prop.name}`,
        monthlyPayment,
        monthlyCashFlow,
        totalMonthlyCashFlow: totalMonthlyCashFlow,
        cumulativeDownPayment: totalDownPayments,
        debtToIncomeRatio: (totalMonthlyDebt / (personalIncome / 12)) * 100
      };
    });
    
    const finalDebtToIncomeRatio = (totalMonthlyDebt / (personalIncome / 12)) * 100;
    
    // 10-year projection
    const yearlyProjection = Array.from({ length: 11 }, (_, year) => {
      const growthFactor = Math.pow(1 + annualIncomeGrowth / 100, year);
      const rentGrowthFactor = Math.pow(1 + annualRentGrowth / 100, year);
      
      const projectedIncome = personalIncome * growthFactor;
      const projectedMonthlyIncome = projectedIncome / 12;
      
      // Calculate projected rental income and cash flow
      let projectedTotalRent = 0;
      let projectedTotalCashFlow = 0;
      let remainingMonthlyDebt = 0;
      
      properties.forEach(prop => {
        const projectedRent = prop.monthlyRent * rentGrowthFactor;
        const loanAmount = prop.purchasePrice - prop.downPayment;
        const originalMonthlyPayment = calculateMonthlyPayment(loanAmount, prop.interestRate, prop.loanTerm);
        const monthsElapsed = year * 12;
        
        // Calculate remaining balance after payments
        const monthlyRate = prop.interestRate / 100 / 12;
        const totalPayments = prop.loanTerm * 12;
        let remainingBalance = loanAmount;
        
        if (monthsElapsed > 0 && monthsElapsed < totalPayments) {
          // Calculate remaining balance using amortization formula
          const paymentsRemaining = totalPayments - monthsElapsed;
          remainingBalance = originalMonthlyPayment * 
            ((Math.pow(1 + monthlyRate, paymentsRemaining) - 1) / 
             (monthlyRate * Math.pow(1 + monthlyRate, paymentsRemaining)));
        } else if (monthsElapsed >= totalPayments) {
          remainingBalance = 0;
        }
        
        // Calculate current monthly payment (0 if loan is paid off)
        const currentMonthlyPayment = remainingBalance > 0 ? originalMonthlyPayment : 0;
        
        const monthlyTaxInsurance = (prop.propertyTax + prop.insurance) / 12;
        const totalMonthlyExpenses = currentMonthlyPayment + monthlyTaxInsurance + prop.monthlyExpenses;
        const projectedCashFlow = projectedRent - totalMonthlyExpenses;
        
        projectedTotalRent += projectedRent;
        projectedTotalCashFlow += projectedCashFlow;
        remainingMonthlyDebt += currentMonthlyPayment;
      });
      
      const projectedDTI = remainingMonthlyDebt > 0 ? (remainingMonthlyDebt / projectedMonthlyIncome) * 100 : 0;
      
      return {
        year,
        personalIncome: projectedIncome,
        monthlyIncome: projectedMonthlyIncome,
        totalRentalIncome: projectedTotalRent * 12, // Convert to annual
        totalCashFlow: projectedTotalCashFlow,
        debtToIncomeRatio: projectedDTI,
        totalAnnualIncome: projectedIncome + (projectedTotalCashFlow * 12) // Annual total income
      };
    });
    
    return {
      propertyDetails,
      totalMonthlyCashFlow,
      totalMonthlyDebt,
      totalDownPayments,
      totalPropertyValue,
      debtToIncomeRatio: finalDebtToIncomeRatio,
      yearlyProjection
    };
  }, [properties, personalIncome, annualIncomeGrowth, annualRentGrowth]);

  return (
    <div className="max-w-7xl mx-auto p-6 bg-gray-50 min-h-screen">
      <div className="bg-white rounded-lg shadow-lg p-6 mb-6">
        <h1 className="text-3xl font-bold text-gray-800 mb-6 flex items-center">
          <Home className="mr-3 text-blue-600" />
          Real Estate Portfolio Analyzer
        </h1>
        
        {/* Personal Income Input */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div className="p-4 bg-blue-50 rounded-lg">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Annual Personal Income ($)
            </label>
            <input
              type="number"
              value={personalIncome}
              onChange={(e) => setPersonalIncome(parseFloat(e.target.value) || 0)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="100000"
            />
          </div>
          
          <div className="p-4 bg-green-50 rounded-lg">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Annual Income Growth (%)
            </label>
            <input
              type="number"
              step="0.1"
              value={annualIncomeGrowth}
              onChange={(e) => setAnnualIncomeGrowth(parseFloat(e.target.value) || 0)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
              placeholder="3.0"
            />
          </div>
          
          <div className="p-4 bg-purple-50 rounded-lg">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Annual Rent Growth (%)
            </label>
            <input
              type="number"
              step="0.1"
              value={annualRentGrowth}
              onChange={(e) => setAnnualRentGrowth(parseFloat(e.target.value) || 0)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
              placeholder="2.5"
            />
          </div>
        </div>
        
        {/* Key Metrics Summary */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div className="bg-green-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-green-600">Monthly Cash Flow</p>
                <p className="text-2xl font-bold text-green-700">
                  ${portfolioMetrics.totalMonthlyCashFlow.toFixed(0)}
                </p>
              </div>
              {portfolioMetrics.totalMonthlyCashFlow > 0 ? 
                <TrendingUp className="text-green-600" /> : 
                <TrendingDown className="text-red-600" />
              }
            </div>
          </div>
          
          <div className="bg-red-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-red-600">Debt-to-Income Ratio</p>
                <p className="text-2xl font-bold text-red-700">
                  {portfolioMetrics.debtToIncomeRatio.toFixed(1)}%
                </p>
              </div>
              <DollarSign className="text-red-600" />
            </div>
          </div>
          
          <div className="bg-purple-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-purple-600">Total Down Payments</p>
                <p className="text-2xl font-bold text-purple-700">
                  ${portfolioMetrics.totalDownPayments.toLocaleString()}
                </p>
              </div>
              <Home className="text-purple-600" />
            </div>
          </div>
          
          <div className="bg-blue-50 p-4 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-blue-600">Portfolio Value</p>
                <p className="text-2xl font-bold text-blue-700">
                  ${portfolioMetrics.totalPropertyValue.toLocaleString()}
                </p>
              </div>
              <TrendingUp className="text-blue-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <div className="bg-white rounded-lg shadow-lg p-6">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Cash Flow & Debt-to-Income Growth</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={portfolioMetrics.propertyDetails}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="property" label={{ value: 'Property #', position: 'insideBottom', offset: -10 }} />
              <YAxis yAxisId="left" label={{ value: 'Cash Flow ($)', angle: -90, position: 'insideLeft' }} />
              <YAxis yAxisId="right" orientation="right" label={{ value: 'DTI Ratio (%)', angle: 90, position: 'insideRight' }} />
              <Tooltip 
                formatter={(value, name) => [
                  name === 'totalMonthlyCashFlow' ? `${(+value).toFixed(0)}` : 
                  name === 'debtToIncomeRatio' ? `${(+value).toFixed(1)}%` : value,
                  name === 'totalMonthlyCashFlow' ? 'Total Monthly Cash Flow' : 
                  name === 'debtToIncomeRatio' ? 'Debt-to-Income Ratio' : name
                ]}
              />
              <Legend />
              <Line yAxisId="left" type="monotone" dataKey="totalMonthlyCashFlow" stroke="#10b981" strokeWidth={3} name="Cumulative Cash Flow" />
              <Line yAxisId="right" type="monotone" dataKey="debtToIncomeRatio" stroke="#ef4444" strokeWidth={3} name="Debt-to-Income Ratio" />
            </LineChart>
          </ResponsiveContainer>
        </div>
        
        <div className="bg-white rounded-lg shadow-lg p-6">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Individual Property Cash Flow</h3>
          <ResponsiveContainer width="100%" height={400}>
            <BarChart data={portfolioMetrics.propertyDetails}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="property" label={{ value: 'Property #', position: 'insideBottom', offset: -2 }} />
              <YAxis label={{ value: 'Property Cash Flow ($)', angle: -90, position: 'insideLeft' }} />
              <Tooltip formatter={(value) => [`${(+value).toFixed(0)}`, 'Monthly Cash Flow']} />
              <Bar 
                dataKey="monthlyCashFlow" 
                name="Monthly Cash Flow"
              >
                {portfolioMetrics.propertyDetails.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.monthlyCashFlow >= 0 ? '#10b981' : '#ef4444'} />
                ))}
              </Bar>
              <ReferenceLine y={0} stroke="#000" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* 10-Year Projection Chart */}
      <div className="bg-white rounded-lg shadow-lg p-6 mb-6">
        <h3 className="text-lg font-semibold text-gray-800 mb-4">10-Year Income & Debt-to-Income Projection</h3>
        <ResponsiveContainer width="100%" height={400}>
          <LineChart data={portfolioMetrics.yearlyProjection}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis 
              dataKey="year" 
              label={{ value: 'Years from Now', position: 'insideBottom', offset: -10 }} 
            />
            <YAxis 
              yAxisId="left" 
              label={{ value: 'Monthly Income ($)', angle: -90, position: 'insideLeft' }}
              tickFormatter={(value) => `${(value / 1000).toFixed(0)}k`}
            />
            <YAxis 
              yAxisId="right" 
              orientation="right" 
              label={{ value: 'Debt-to-Income Ratio (%)', angle: 90, position: 'insideRight' }}
              domain={[0, 50]}
            />
            <Tooltip 
              formatter={(value, name) => {
                if (name === 'monthlyIncome' || name === 'totalMonthlyIncome') {
                  return [`${(+value).toFixed(0)}`, name === 'monthlyIncome' ? 'Personal Monthly Income' : 'Total Monthly Income'];
                }
                if (name === 'debtToIncomeRatio') {
                  return [`${(+value).toFixed(1)}%`, 'Debt-to-Income Ratio'];
                }
                return [value, name];
              }}
              labelFormatter={(year) => `Year ${year}`}
            />
            <Legend />
            <Line 
              yAxisId="left" 
              type="monotone" 
              dataKey="monthlyIncome" 
              stroke="#3b82f6" 
              strokeWidth={3} 
              name="Personal Monthly Income"
            />
            <Line 
              yAxisId="left" 
              type="monotone" 
              dataKey="totalMonthlyIncome" 
              stroke="#10b981" 
              strokeWidth={3} 
              name="Total Monthly Income (Personal + Rental)"
            />
            <Line 
              yAxisId="right" 
              type="monotone" 
              dataKey="debtToIncomeRatio" 
              stroke="#ef4444" 
              strokeWidth={3} 
              name="Debt-to-Income Ratio"
              strokeDasharray="5 5"
            />
          </LineChart>
        </ResponsiveContainer>
        <div className="mt-4 text-sm text-gray-600">
          <p>This projection assumes:</p>
          <ul className="list-disc list-inside mt-2 space-y-1">
            <li>Personal income grows at {annualIncomeGrowth}% annually</li>
            <li>Rental income grows at {annualRentGrowth}% annually</li>
            <li>Mortgage principal is paid down according to amortization schedule</li>
            <li>Property expenses remain constant (conservative estimate)</li>
            <li>DTI ratio improves as mortgages are paid off and income grows</li>
          </ul>
        </div>
      </div>

      {/* Property Management */}
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-lg font-semibold text-gray-800">Property Portfolio</h3>
          <button
            onClick={addProperty}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 flex items-center"
          >
            <Plus className="w-4 h-4 mr-2" />
            Add Property
          </button>
        </div>
        
        <div className="space-y-4">
          {properties.map((property) => {
            const loanAmount = property.purchasePrice - property.downPayment;
            const monthlyPayment = calculateMonthlyPayment(loanAmount, property.interestRate, property.loanTerm);
            const monthlyTaxInsurance = (property.propertyTax + property.insurance) / 12;
            const totalMonthlyExpenses = monthlyPayment + monthlyTaxInsurance + property.monthlyExpenses;
            const monthlyCashFlow = property.monthlyRent - totalMonthlyExpenses;
            
            return (
              <div key={property.id} className="border border-gray-200 rounded-lg p-4">
                <div className="flex justify-between items-center mb-4">
                  <div className="flex-1 mr-4">
                    <input
                      type="text"
                      value={property.name}
                      onChange={(e) => updateProperty(property.id, 'name', e.target.value)}
                      className="text-md font-semibold text-gray-700 bg-transparent border-none outline-none focus:bg-white focus:border focus:border-blue-500 focus:rounded px-2 py-1 w-full"
                      placeholder="Property Name"
                    />
                  </div>
                  <button
                    onClick={() => removeProperty(property.id)}
                    className="text-red-600 hover:text-red-800 flex-shrink-0"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
                
                <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-4">
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Purchase Price</label>
                    <input
                      type="number"
                      value={property.purchasePrice}
                      onChange={(e) => updateProperty(property.id, 'purchasePrice', e.target.value)}
                      className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Down Payment</label>
                    <input
                      type="number"
                      value={property.downPayment}
                      onChange={(e) => updateProperty(property.id, 'downPayment', e.target.value)}
                      className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Interest Rate (%)</label>
                    <input
                      type="number"
                      step="0.1"
                      value={property.interestRate}
                      onChange={(e) => updateProperty(property.id, 'interestRate', e.target.value)}
                      className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Loan Term (years)</label>
                    <input
                      type="number"
                      value={property.loanTerm}
                      onChange={(e) => updateProperty(property.id, 'loanTerm', e.target.value)}
                      className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Monthly Rent</label>
                    <input
                      type="number"
                      value={property.monthlyRent}
                      onChange={(e) => updateProperty(property.id, 'monthlyRent', e.target.value)}
                      className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Monthly Expenses</label>
                    <input
                      type="number"
                      value={property.monthlyExpenses}
                      onChange={(e) => updateProperty(property.id, 'monthlyExpenses', e.target.value)}
                      className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Annual Property Tax</label>
                    <input
                      type="number"
                      value={property.propertyTax}
                      onChange={(e) => updateProperty(property.id, 'propertyTax', e.target.value)}
                      className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Annual Insurance</label>
                    <input
                      type="number"
                      value={property.insurance}
                      onChange={(e) => updateProperty(property.id, 'insurance', e.target.value)}
                      className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                    />
                  </div>
                </div>
                
                <div className="mt-3 pt-3 border-t border-gray-200 grid grid-cols-3 gap-4 text-sm">
                  <div>
                    <span className="text-gray-600">Monthly Payment: </span>
                    <span className="font-semibold">${monthlyPayment.toFixed(0)}</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Total Monthly Expenses: </span>
                    <span className="font-semibold">${totalMonthlyExpenses.toFixed(0)}</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Monthly Cash Flow: </span>
                    <span className={`font-semibold ${monthlyCashFlow >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                      ${monthlyCashFlow.toFixed(0)}
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default RealEstateAnalyzer;