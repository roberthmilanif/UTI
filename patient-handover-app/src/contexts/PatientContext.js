import React, { createContext, useState, useCallback } from 'react';

export const PatientContext = createContext();

const initialPatients = [
  {
    id: '1',
    name: 'João Ninguém', // John Doe
    dateOfBirth: '1985-01-15',
    medicalHistory: 'Hipertensão, Diabetes Tipo 2', // Hypertension, Type 2 Diabetes
    medications: 'Lisinopril 10mg OD\nMetformina 500mg BD', // Lisinopril 10mg OD\nMetformin 500mg BD
    labResults: 'HbA1c: 7.5% (2023-10-01)\nCreatinina: 1.2 mg/dL (2023-10-01)', // HbA1c: 7.5% (2023-10-01)\nCreatinine: 1.2 mg/dL (2023-10-01)
    evolutionNotes: 'Paciente relata bem-estar. Pressão arterial e níveis de glicose estáveis. Continuar plano de tratamento atual.', // Patient reports feeling well. Blood pressure and glucose levels are stable. Continue current treatment plan.
  },
  {
    id: '2',
    name: 'Maria Silva', // Jane Smith (common Brazilian name)
    dateOfBirth: '1990-06-22',
    medicalHistory: 'Asma', // Asthma
    medications: 'Inalador de Albuterol PRN', // Albuterol Inhaler PRN
    labResults: 'Espirometria: VEF1 80% previsto (2023-09-15)', // Spirometry: FEV1 80% predicted (2023-09-15)
    evolutionNotes: 'Acompanhamento para manejo de asma. Paciente relata uso ocasional do inalador, especialmente com exercícios.', // Follow up for asthma management. Patient reports occasional use of inhaler, especially with exercise.
  },
];

export const PatientProvider = ({ children }) => {
  const [patients, setPatients] = useState(initialPatients);
  const [selectedPatientId, setSelectedPatientId] = useState(null);

  const addPatient = useCallback((patient) => {
    setPatients(prevPatients => [...prevPatients, { ...patient, id: Date.now().toString() }]);
  }, []);

  const editPatient = useCallback((updatedPatient) => {
    setPatients(prevPatients =>
      prevPatients.map(p => (p.id === updatedPatient.id ? updatedPatient : p))
    );
  }, []);

  const selectPatient = useCallback((patientId) => {
    setSelectedPatientId(patientId);
  }, []);

  const selectedPatient = patients.find(p => p.id === selectedPatientId) || null;

  return (
    <PatientContext.Provider
      value={{
        patients,
        selectedPatient,
        addPatient,
        editPatient,
        selectPatient,
        setSelectedPatientId // Exposing this to allow deselecting or direct manipulation if needed
      }}
    >
      {children}
    </PatientContext.Provider>
  );
};
