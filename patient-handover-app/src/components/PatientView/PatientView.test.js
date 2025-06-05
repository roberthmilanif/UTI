import React from 'react';
import { render, screen } from '@testing-library/react';
import { PatientContext } from '../../contexts/PatientContext';
import PatientView from './PatientView';

// Using the translated mock data structure from PatientContext.js for consistency
const mockPtPtBr = {
  id: '1',
  name: 'João Ninguém',
  dateOfBirth: '1985-01-15',
  medicalHistory: 'Hipertensão, Diabetes Tipo 2',
  medications: 'Lisinopril 10mg OD\nMetformina 500mg BD',
  labResults: 'HbA1c: 7.5% (2023-10-01)\nCreatinina: 1.2 mg/dL (2023-10-01)',
  evolutionNotes: 'Paciente relata bem-estar. Pressão arterial e níveis de glicose estáveis. Continuar plano de tratamento atual.',
};


// Helper to render with context
const renderWithContext = (
  ui,
  { providerProps, ...renderOptions }
) => {
  return render(
    <PatientContext.Provider value={providerProps}>{ui}</PatientContext.Provider>,
    renderOptions
  );
};

describe('PatientView', () => {
  let providerProps;

  beforeEach(() => {
    providerProps = {
      patients: [],
      selectedPatient: null,
      selectPatient: jest.fn(),
      addPatient: jest.fn(),
      editPatient: jest.fn(),
      setSelectedPatientId: jest.fn(),
    };
  });

  test('displays "Selecione um paciente..." message when no patient is selected', () => {
    renderWithContext(<PatientView />, { providerProps });
    expect(screen.getByText(/selecione um paciente para ver os detalhes/i)).toBeInTheDocument();
    // Check main title for the view when no patient is selected
    expect(screen.getByRole('heading', {name: /detalhes do paciente/i})).toBeInTheDocument();
  });

  test('renders details of a selected patient from context in Portuguese', () => {
    providerProps.selectedPatient = mockPtPtBr;
    renderWithContext(<PatientView />, { providerProps });

    // Check for patient's name in the title
    expect(screen.getByRole('heading', { name: `Detalhes do Paciente: ${mockPtPtBr.name}` })).toBeInTheDocument();

    // Check section titles
    expect(screen.getByRole('heading', { name: /Informações Básicas/i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /Histórico Médico:/i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /Medicamentos:/i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /Resultados de Exames:/i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /Notas de Evolução:/i })).toBeInTheDocument();

    // Check for a few key pieces of information (already translated in mockPtPtBr)
    expect(screen.getByText(mockPtPtBr.dateOfBirth)).toBeInTheDocument(); // Label is "Data de Nascimento:"
    expect(screen.getByText((content, element) => content.startsWith('Data de Nascimento:') && content.includes(mockPtPtBr.dateOfBirth))).toBeInTheDocument();


    expect(screen.getByText(mockPtPtBr.medicalHistory)).toBeInTheDocument();
    expect(screen.getByText(/Lisinopril 10mg OD/i)).toBeInTheDocument();
    expect(screen.getByText(/Metformina 500mg BD/i)).toBeInTheDocument();
    expect(screen.getByText(/HbA1c: 7.5% \(2023-10-01\)/i)).toBeInTheDocument();
    expect(screen.getByText(/Creatinina: 1.2 mg\/dL \(2023-10-01\)/i)).toBeInTheDocument();
    expect(screen.getByText(mockPtPtBr.evolutionNotes)).toBeInTheDocument();
  });

  test('renders multi-line fields correctly (e.g., Medications)', () => {
    providerProps.selectedPatient = {
      ...mockPtPtBr,
      medications: "Med1 Linha1\nMed2 Linha2",
    };
    renderWithContext(<PatientView />, { providerProps });

    // Check within the "Medicamentos" section
    const medicationsSection = screen.getByRole('heading', { name: /Medicamentos:/i }).closest('div');

    expect(medicationsSection).toHaveTextContent("Med1 Linha1");
    expect(medicationsSection).toHaveTextContent("Med2 Linha2");

    // Check for <br />. This assumes the renderMultiLineText helper splits by '\n' and adds <br />.
    // This test is a bit fragile if the rendering method changes significantly.
    const med1Text = screen.getByText("Med1 Linha1");
    expect(med1Text.nextSibling.tagName).toBe('BR');
  });

});
