import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter, useNavigate } from 'react-router-dom'; // MemoryRouter for Link, useNavigate for mocking
import { PatientContext, PatientProvider } from '../../contexts/PatientContext'; // Import PatientProvider to wrap, or use a custom mock
import PatientList from './PatientList';

// Mock useNavigate
const mockedNavigate = jest.fn();
jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockedNavigate,
}));

// Using translated mock patient names for consistency, though PatientList only displays names.
const mockPatients = [
  { id: '1', name: 'João Ninguém', medicalHistory: 'Hipertensão' }, // John Doe
  { id: '2', name: 'Maria Silva', medicalHistory: 'Asma' },    // Jane Smith
];

// Helper to render with context
const renderWithContext = (
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


describe('PatientList', () => {
  let mockSelectPatient;
  let providerProps;

  beforeEach(() => {
    mockSelectPatient = jest.fn();
    mockedNavigate.mockClear();
    providerProps = {
      patients: [],
      selectedPatient: null,
      selectPatient: mockSelectPatient,
      addPatient: jest.fn(),
      editPatient: jest.fn(),
      setSelectedPatientId: jest.fn(),
    };
  });

  test('renders "Nenhum paciente disponível..." message when patient list is empty', () => {
    renderWithContext(<PatientList />, { providerProps });
    expect(screen.getByText(/nenhum paciente disponível/i)).toBeInTheDocument();
    expect(screen.getByText(/clique em "Adicionar Novo Paciente" para criar um/i)).toBeInTheDocument();
  });

  test('renders page title "Lista de Pacientes"', () => {
    renderWithContext(<PatientList />, { providerProps });
    expect(screen.getByRole('heading', { name: /lista de pacientes/i })).toBeInTheDocument();
  });

  test('renders a list of patients provided via context', () => {
    providerProps.patients = mockPatients;
    renderWithContext(<PatientList />, { providerProps });

    expect(screen.getByText('João Ninguém')).toBeInTheDocument();
    expect(screen.getByText('Maria Silva')).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: /editar/i })).toHaveLength(mockPatients.length); // Edit
  });

  test('calls selectPatient when a patient item (info part) is clicked', () => {
    providerProps.patients = mockPatients;
    renderWithContext(<PatientList />, { providerProps });

    const firstPatientInfo = screen.getByText('João Ninguém');
    fireEvent.click(firstPatientInfo);
    expect(mockSelectPatient).toHaveBeenCalledWith('1');
  });

  test('highlights the selected patient', () => {
    providerProps.patients = mockPatients;
    providerProps.selectedPatient = mockPatients[0]; // João Ninguém is selected
    renderWithContext(<PatientList />, { providerProps });

    const joaoListItem = screen.getByText('João Ninguém').closest('li');
    expect(joaoListItem).toHaveClass('selected');

    const mariaListItem = screen.getByText('Maria Silva').closest('li');
    expect(mariaListItem).not.toHaveClass('selected');
  });

  test('calls selectPatient and navigates when "Editar" button is clicked', () => { // Edit
    providerProps.patients = mockPatients;
    renderWithContext(<PatientList />, { providerProps });

    const editButtons = screen.getAllByRole('button', { name: /editar/i }); // Edit
    fireEvent.click(editButtons[0]);

    expect(mockSelectPatient).toHaveBeenCalledWith('1'); // João Ninguém's ID
    expect(mockedNavigate).toHaveBeenCalledWith('/edit-patient');
  });
});
