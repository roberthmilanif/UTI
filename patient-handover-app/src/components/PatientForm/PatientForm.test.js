import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { PatientContext } from '../../contexts/PatientContext';
import PatientForm from './PatientForm';

// Mock useNavigate
const mockedNavigate = jest.fn();
jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockedNavigate,
}));

// Using translated mock patient data for edit mode tests
const mockPtBrSelectedPatient = {
  id: '1',
  name: 'João Ninguém',
  dateOfBirth: '1990-01-01',
  medicalHistory: 'Hipertensão',
  medications: 'Lisinopril 10mg OD',
  labResults: 'HbA1c: 7.0%',
  evolutionNotes: 'Condição estável.',
};

// Helper to render with context and router
const renderWithProviders = (
  ui,
  { providerProps, ...renderOptions }
) => {
  return render(
    <MemoryRouter>
      <PatientContext.Provider value={providerProps}>{ui}</PatientContext.Provider>
    </MemoryRouter>,
    renderOptions
  );
};

describe('PatientForm', () => {
  let mockAddPatient;
  let mockEditPatient;
  let mockSetSelectedPatientId;
  let providerProps;

  beforeEach(() => {
    mockAddPatient = jest.fn();
    mockEditPatient = jest.fn();
    mockSetSelectedPatientId = jest.fn();
    mockedNavigate.mockClear();

    providerProps = {
      patients: [],
      selectedPatient: null,
      addPatient: mockAddPatient,
      editPatient: mockEditPatient,
      selectPatient: jest.fn(),
      setSelectedPatientId: mockSetSelectedPatientId,
    };
  });

  describe('Modo Adicionar Novo Paciente', () => {
    test('renderiza título "Adicionar Novo Paciente" e campos vazios', () => {
      renderWithProviders(<PatientForm />, { providerProps });
      expect(screen.getByRole('heading', { name: /adicionar novo paciente/i })).toBeInTheDocument();
      expect(screen.getByLabelText(/nome:/i)).toHaveValue('');
      expect(screen.getByLabelText(/data de nascimento:/i)).toHaveValue('');
      expect(screen.getByLabelText(/histórico médico:/i)).toHaveValue('');
      expect(screen.getByLabelText(/medicamentos:/i)).toHaveValue('');
      expect(screen.getByLabelText(/resultados de exames:/i)).toHaveValue('');
      expect(screen.getByLabelText(/notas de evolução:/i)).toHaveValue('');
    });

    test('chama addPatient, setSelectedPatientId(null), e navega ao submeter', async () => {
      renderWithProviders(<PatientForm />, { providerProps });

      fireEvent.change(screen.getByLabelText(/nome:/i), { target: { value: 'Novo Paciente PT' } });
      fireEvent.change(screen.getByLabelText(/data de nascimento:/i), { target: { value: '2001-06-06' } });
      fireEvent.change(screen.getByLabelText(/histórico médico:/i), { target: { value: 'Nenhum' } });
      fireEvent.change(screen.getByLabelText(/medicamentos:/i), { target: { value: 'Med X\nMed Y' } });
      fireEvent.change(screen.getByLabelText(/resultados de exames:/i), { target: { value: 'Tudo OK' } });
      fireEvent.change(screen.getByLabelText(/notas de evolução:/i), { target: { value: 'Melhorando' } });

      fireEvent.click(screen.getByRole('button', { name: /adicionar paciente/i })); // "Add Patient" button

      await waitFor(() => {
        expect(mockAddPatient).toHaveBeenCalledWith({
          name: 'Novo Paciente PT',
          dateOfBirth: '2001-06-06',
          medicalHistory: 'Nenhum',
          medications: 'Med X\nMed Y',
          labResults: 'Tudo OK',
          evolutionNotes: 'Melhorando',
        });
      });
      expect(mockSetSelectedPatientId).toHaveBeenCalledWith(null);
      expect(mockedNavigate).toHaveBeenCalledWith('/');
    });
  });

  describe('Modo Editar Paciente', () => {
    beforeEach(() => {
      providerProps.selectedPatient = mockPtBrSelectedPatient;
    });

    test('renderiza título "Editar Detalhes do Paciente" e campos preenchidos', () => {
      renderWithProviders(<PatientForm />, { providerProps });
      expect(screen.getByRole('heading', { name: /editar detalhes do paciente/i })).toBeInTheDocument();
      expect(screen.getByLabelText(/nome:/i)).toHaveValue(mockPtBrSelectedPatient.name);
      expect(screen.getByLabelText(/data de nascimento:/i)).toHaveValue(mockPtBrSelectedPatient.dateOfBirth);
      expect(screen.getByLabelText(/histórico médico:/i)).toHaveValue(mockPtBrSelectedPatient.medicalHistory);
      expect(screen.getByLabelText(/medicamentos:/i)).toHaveValue(mockPtBrSelectedPatient.medications);
      expect(screen.getByLabelText(/resultados de exames:/i)).toHaveValue(mockPtBrSelectedPatient.labResults);
      expect(screen.getByLabelText(/notas de evolução:/i)).toHaveValue(mockPtBrSelectedPatient.evolutionNotes);
    });

    test('chama editPatient, setSelectedPatientId(null), e navega ao submeter', async () => {
      renderWithProviders(<PatientForm />, { providerProps });
      const historicoAtualizado = 'Hipertensão, Controlada';
      fireEvent.change(screen.getByLabelText(/histórico médico:/i), { target: { value: historicoAtualizado } });

      fireEvent.click(screen.getByRole('button', { name: /salvar alterações/i })); // "Save Changes" button

      await waitFor(() => {
        expect(mockEditPatient).toHaveBeenCalledWith({
          ...mockPtBrSelectedPatient,
          medicalHistory: historicoAtualizado,
        });
      });
      expect(mockSetSelectedPatientId).toHaveBeenCalledWith(null);
      expect(mockedNavigate).toHaveBeenCalledWith('/');
    });
  });

  describe('Funcionalidade Cancelar', () => {
    test('chama setSelectedPatientId(null) e navega ao cancelar (Modo Adicionar)', () => {
      renderWithProviders(<PatientForm />, { providerProps });
      fireEvent.click(screen.getByRole('button', { name: /cancelar/i }));

      expect(mockSetSelectedPatientId).toHaveBeenCalledWith(null);
      expect(mockedNavigate).toHaveBeenCalledWith('/');
      expect(mockAddPatient).not.toHaveBeenCalled();
      expect(mockEditPatient).not.toHaveBeenCalled();
    });

    test('chama setSelectedPatientId(null) e navega ao cancelar (Modo Editar)', () => {
      providerProps.selectedPatient = mockPtBrSelectedPatient;
      renderWithProviders(<PatientForm />, { providerProps });
      fireEvent.click(screen.getByRole('button', { name: /cancelar/i }));

      expect(mockSetSelectedPatientId).toHaveBeenCalledWith(null);
      expect(mockedNavigate).toHaveBeenCalledWith('/');
      expect(mockAddPatient).not.toHaveBeenCalled();
      expect(mockEditPatient).not.toHaveBeenCalled();
    });
  });
});
